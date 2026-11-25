import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/config.dart';
import '../../core/marker_factory.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import 'driver_controller.dart';
import 'driver_widgets.dart';

class DriverHomeScreen extends StatefulWidget {
  final VoidCallback onOpenOrders;
  const DriverHomeScreen({super.key, required this.onOpenOrders});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with AutomaticKeepAliveClientMixin {
  GoogleMapController? _map;
  late final DriverController _ctrl;

  BitmapDescriptor? _icDriver, _icPickup, _icDest;
  double _panelHeight = 240;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<DriverController>();
    _ctrl.addListener(_onCtrl);
    _ctrl.onNewIncoming = (o) {
      if (mounted) {
        showIncomingOrderSheet(context, _ctrl, o, onAccepted: widget.onOpenOrders);
      }
    };
    _loadIcons();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _ctrl.onNewIncoming = null;
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    final r = await Future.wait([
      MarkerFactory.icon(Icons.two_wheeler_rounded, AppColors.primaryDark, width: 54),
      MarkerFactory.icon(Icons.trip_origin_rounded, AppColors.primary, width: 44),
      MarkerFactory.icon(Icons.flag_rounded, AppColors.danger, width: 44),
    ]);
    if (!mounted) return;
    setState(() {
      _icDriver = r[0];
      _icPickup = r[1];
      _icDest = r[2];
    });
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  void _recenter() {
    final pos = _ctrl.position;
    final active = _ctrl.active;
    if (_map == null) return;
    if (active != null) {
      final pts = [
        if (pos != null) pos,
        active.pickup,
        active.dest,
      ];
      _map!.animateCamera(CameraUpdate.newLatLngBounds(Geo.bounds(pts), 60));
    } else if (pos != null) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    }
  }

  Set<Marker> _markers(Order? active, LatLng? pos) {
    final set = <Marker>{};
    if (pos != null) {
      set.add(Marker(
        markerId: const MarkerId('driver_pos'),
        position: pos,
        icon: _icDriver ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 5,
        infoWindow: const InfoWindow(title: 'Lokasi Anda'),
      ));
    }
    if (active != null) {
      set.add(Marker(
        markerId: const MarkerId('order_pickup'),
        position: active.pickup,
        icon: _icPickup ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(title: 'Jemput: ${active.pickupAddress}'),
      ));
      set.add(Marker(
        markerId: const MarkerId('order_dest'),
        position: active.dest,
        icon: _icDest ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Tujuan: ${active.destAddress}'),
      ));
    }
    return set;
  }

  Set<Polyline> _polylines() {
    final pts = _ctrl.route?.points;
    if (pts == null || pts.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route_bg'),
        points: pts,
        color: Colors.white,
        width: 8,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: AppColors.primary,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ctrl = context.watch<DriverController>();
    final auth = context.watch<AuthProvider>();
    final u = auth.user;
    final info = u?.driver;
    final active = ctrl.active;
    final pos = ctrl.position ?? AppConfig.campusCenter;

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: pos, zoom: 16),
          onMapCreated: (c) {
            _map = c;
            _recenter();
          },
          padding: EdgeInsets.only(bottom: _panelHeight + 85, top: 100),
          markers: _markers(active, ctrl.position),
          polylines: _polylines(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        // Top status card & Online switch
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _topStatusCard(ctrl, info),
          ),
        ),
        // Recenter button
        Positioned(
          right: 16,
          bottom: _panelHeight + 96,
          child: FloatingActionButton.small(
            heroTag: 'driver_recenter',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            elevation: 3,
            onPressed: _recenter,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
        // Bottom control / incoming orders / active order panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 96),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  _bottomPanelContent(ctrl, info, active),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _topStatusCard(DriverController ctrl, DriverInfo? info) {
    final approved = info?.approved ?? false;
    final isPending = info?.verificationStatus == 'pending';
    final isRejected = info?.verificationStatus == 'rejected';

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Avatar(ctrl.auth.user?.initials ?? 'D', url: ctrl.auth.user?.avatarUrl, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ctrl.auth.user?.name ?? 'Driver',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ctrl.online ? AppColors.success : AppColors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ctrl.online ? 'Online (Siap terima pesanan)' : 'Offline',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ctrl.online ? AppColors.success : AppColors.grey,
                      ),
                    ),
                  ]),
                ]),
              ),
              ctrl.isTogglingOnline
                  ? const SizedBox(
                      width: 48,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
                        ),
                      ),
                    )
                  : Switch(
                      value: ctrl.online,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) async {
                        if (!approved) {
                          showMsg(
                            context,
                            isPending
                                ? 'Akun Anda sedang dalam proses verifikasi admin sebelum dapat mengaktifkan status online.'
                                : 'Akun Anda belum disetujui untuk online.',
                            error: true,
                          );
                          return;
                        }
                        if (ctrl.active != null) {
                          showMsg(
                            context,
                            'Selesaikan pesanan yang sedang aktif terlebih dahulu sebelum mengubah status online.',
                            error: true,
                          );
                          return;
                        }
                        try {
                          final msg = await ctrl.setOnline(val);
                          if (mounted) showMsg(context, msg);
                        } catch (e) {
                          if (mounted) showError(context, e);
                        }
                      },
                    ),
            ]),
            if (isPending) ...[
              const Divider(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Dokumen Anda sedang diverifikasi admin sebelum dapat online.',
                        style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.3)),
                  ),
                ]),
              ),
            ] else if (isRejected) ...[
              const Divider(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pendaftaran ditolak: ${info?.rejectionReason ?? "-"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.3)),
                  ),
                ]),
              ),
            ] else if ((info?.penaltyPoints ?? 0) > 0) ...[
              const Divider(height: 16),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Poin penalti: ${info!.penaltyPoints} / ${info.penaltyThreshold}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bottomPanelContent(DriverController ctrl, DriverInfo? info, Order? active) {
    if (active != null) {
      return DriverOrderCard(order: active);
    }

    if (!ctrl.online) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.two_wheeler_rounded, size: 44, color: AppColors.grey),
          const SizedBox(height: 8),
          const Text('Status Driver: Offline',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Aktifkan status online untuk mulai menerima pesanan mahasiswa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              if (!(info?.approved ?? false)) {
                showMsg(
                  context,
                  (info?.verificationStatus == 'pending')
                      ? 'Akun Anda sedang dalam proses verifikasi admin sebelum dapat mengaktifkan status online.'
                      : 'Akun Anda belum disetujui untuk online.',
                  error: true,
                );
                return;
              }
              try {
                final msg = await ctrl.setOnline(true);
                if (mounted) showMsg(context, msg);
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text('Aktifkan Status Online', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }

    // Online & waiting for incoming orders (maks 1 pesanan masuk per driver agar tidak menumpuk)
    final incoming = ctrl.incoming.where((e) => !ctrl.dismissed.contains(e.id)).toList();
    if (incoming.isNotEmpty) {
      final inc = incoming.first;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Pesanan Baru Masuk Untuk Anda',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
            StatusChip(inc.isQris ? 'QRIS' : 'Tunai', inc.isQris ? AppColors.info : AppColors.primary),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Avatar(inc.customerName.isEmpty ? 'C' : inc.customerName[0].toUpperCase(), size: 38, bg: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inc.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('${Fmt.km(inc.distanceKm)} • ${inc.code}',
                              style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                        ],
                      ),
                    ),
                    Text(Fmt.rupiah(inc.totalFare),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDark)),
                  ],
                ),
                const Divider(height: 18),
                RouteSummary(pickup: inc.pickupAddress, dest: inc.destAddress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          minimumSize: const Size.fromHeight(42),
                        ),
                        onPressed: () async {
                          await ctrl.reject(inc);
                          if (mounted) {
                            showMsg(context, 'Pesanan ditolak & dialihkan ke driver lain');
                          }
                        },
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                        onPressed: () => showIncomingOrderSheet(context, ctrl, inc, onAccepted: widget.onOpenOrders),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Lihat & Terima'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('Menunggu pesanan baru...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Tetap buka aplikasi agar sistem dapat mendeteksi Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 12.5)),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => ctrl.setOnline(false),
          child: const Text('Nonaktifkan (Offline)'),
        ),
      ],
    );
  }
}

