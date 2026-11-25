"use client";

import { useEffect, useRef } from "react";

export interface LiquidGlassTabBarProps {
  /** Labels for the three tabs (Home, Analytics, Account). */
  labels?: [string, string, string];
  /** Tab selected on mount (0-2). */
  defaultIndex?: number;
  /** Called when a tab is clicked. */
  onChange?: (index: number) => void;
  className?: string;
}

const W = 1920;
const H = 1080;

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@500&display=swap');
.lgt{position:relative;width:100%;height:100vh;min-height:360px;overflow:hidden;
  --gv:linear-gradient(90deg,rgba(28,36,44,.05) 0 2px,transparent 2px);
  --gh:linear-gradient(rgba(28,36,44,.05) 0 2px,transparent 2px);
  --wash:linear-gradient(107deg,#c1cacc 33.333%,#99a1a5 50%,#71787f 66.667%);
  --sides:linear-gradient(90deg,#000 0 120px,transparent 175px calc(100% - 175px),#000 calc(100% - 120px));
  background:#99a1a5;font-family:Inter,-apple-system,"SF Pro Text",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.lgt *{box-sizing:border-box;margin:0;padding:0}
.lgt-stage{position:absolute;left:50%;top:50%;width:${W}px;height:${H}px;transform-origin:0 0}
/* every see-through surface paints the page background shifted by its own page offset (--x,--y) */
.lgt-bg,.lgt .see{background:var(--top,linear-gradient(transparent,transparent)),
  var(--gv) calc(213px - var(--x,0px)) calc(0px - var(--y,0px))/290px ${H}px,
  var(--gh) calc(0px - var(--x,0px)) calc(138px - var(--y,0px))/${W}px 255px,
  var(--wash) calc(-${W}px - var(--x,0px)) calc(-${H}px - var(--y,0px))/${W*3}px ${H*3}px no-repeat}
.lgt-bg{position:absolute;left:-${W}px;top:-${H}px;width:${W*3}px;height:${H*3}px;--x:-${W}px;--y:-${H}px}
.lgt .pill{position:absolute;left:330px;top:395px;width:1267px;height:292px;border-radius:146px;background:linear-gradient(135deg,#084d2a,#0b6b3a);z-index:1;
  box-shadow:0 40px 120px 4px rgba(8,77,42,.35),0 8px 24px -8px rgba(0,0,0,.18)}
.lgt .lens{position:absolute;top:338px;left:275px;width:490px;height:410px;border-radius:150px;z-index:2;
  box-shadow:0 18px 34px -16px rgba(8,77,42,.38)}
.lgt .clip{position:absolute;inset:0;border-radius:150px;overflow:hidden;box-shadow:inset 0 0 16px 1px rgba(0,0,0,.07)}
.lgt .glass{position:absolute;inset:0;--x:var(--L);--y:338px;
  --top:linear-gradient(rgba(8,77,42,.22) 0,rgba(11,107,58,.14) 57px,rgba(11,107,58,.14) 349px,rgba(255,255,255,.22) 410px)}
.lgt .refr{position:absolute;top:0;left:55px;width:1267px;height:410px;border-radius:146px/205px;overflow:hidden}
.lgt .wing{position:absolute;left:146px;right:146px;background:#0b6b3a}
.lgt .wing.t{top:0;height:60px}
.lgt .wing.b{top:346px;bottom:0}
.lgt .body{position:absolute;left:0;right:0;top:57px;height:292px;border-radius:146px;background:linear-gradient(135deg,#0a5c32,#0e8347)}
.lgt .band{position:absolute;left:87px;right:87px}
.lgt .band.t{top:0;height:57px;border-radius:46px 46px 30px 30px/31px 31px 26px 26px;
  --x:calc(var(--L) + 87px);--y:338px;--top:linear-gradient(rgba(8,77,42,.2),rgba(11,107,58,.12))}
.lgt .band.b{left:78px;right:78px;top:349px;height:61px;border-radius:26px 26px 0 0/22px 22px 0 0;
  --x:calc(var(--L) + 78px);--y:687px;--top:linear-gradient(rgba(11,107,58,.12),rgba(255,255,255,.2))}
.lgt .lc{position:absolute;top:0;left:-55px;width:490px;height:410px}
.lgt .fr{position:absolute;left:87px;right:87px;
  box-shadow:inset 3px 0 2px -1px rgba(52,211,153,.9),inset -3px 0 2px -1px rgba(52,211,153,.9);
  -webkit-mask:linear-gradient(90deg,#000 0 34px,transparent 56px calc(100% - 56px),#000 calc(100% - 34px));
  mask:linear-gradient(90deg,#000 0 34px,transparent 56px calc(100% - 56px),#000 calc(100% - 34px))}
.lgt .fr.t{top:0;height:57px;border-radius:46px 46px 30px 30px/31px 31px 26px 26px}
.lgt .fr.b{left:78px;right:78px;top:349px;height:61px;border-radius:26px 26px 0 0/22px 22px 0 0}
.lgt .glow{position:absolute;inset:0;border-radius:150px;box-shadow:inset 0 0 40px 10px rgba(167,243,208,.75);
  -webkit-mask:var(--sides);mask:var(--sides)}
.lgt .rim{position:absolute;top:338px;left:275px;width:490px;height:410px;border-radius:150px;z-index:4;pointer-events:none;
  box-shadow:inset 0 0 0 1.5px rgba(209,250,229,.7),inset 0 2px 1px -1px rgba(255,255,255,.95),inset 0 -2px 1px -1px rgba(255,255,255,.7)}
.lgt .item{all:unset;cursor:pointer;-webkit-tap-highlight-color:transparent;position:absolute;top:504px;width:240px;margin-left:-120px;z-index:3;display:flex;flex-direction:column;align-items:center;
  transition:transform .32s cubic-bezier(.2,.8,.2,1)}
.lgt .ic{height:72px;display:block;color:#b7dfc8;transition:color .24s ease,filter .24s ease}
.lgt .lbl{margin-top:33px;font-size:35px;line-height:34px;font-weight:500;letter-spacing:-.01em;color:#fff;white-space:nowrap;opacity:0;transition:opacity .24s ease}
.lgt .item:focus-visible .ic{outline:3px solid rgba(70,120,255,.9);outline-offset:10px;border-radius:12px}
.lgt .item.on{transform:translateY(-34px)}
.lgt .item.on .ic{color:#fff;filter:drop-shadow(0 0 3px rgba(255,255,255,.9)) drop-shadow(0 0 10px rgba(255,255,255,.45))}
.lgt .item.on .lbl{opacity:1}
`;

// lens centre and each tab's x per active tab (stage px)
const S = [
  { lens: 520, x: [538, 977, 1404] },
  { lens: 958, x: [492, 960, 1431] },
  { lens: 1399, x: [505, 925, 1392] },
];
const PL = 330;

export function LiquidGlassTabBar({
  labels = ["Home", "Analytics", "Account"],
  defaultIndex = 0,
  onChange,
  className = "",
}: LiquidGlassTabBarProps) {
  const root = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const lens = useRef<HTMLDivElement>(null);
  const rim = useRef<HTMLDivElement>(null);
  const refr = useRef<HTMLDivElement>(null);
  const refr2 = useRef<HTMLDivElement>(null);
  const lc = useRef<HTMLDivElement>(null);
  const items = useRef<(HTMLButtonElement | null)[]>([]);
  const go = useRef<(n: number) => void>(() => {});
  const select = (n: number) => { go.current(n); onChange?.(n); };

  useEffect(() => {
    const r = root.current!, st = stage.current!;
    // fit the 1920x1080 stage into the container
    const fit = () => {
      const s = Math.min(r.clientWidth / W, r.clientHeight / H);
      st.style.transform = `scale(${s}) translate(-50%,-50%)`;
    };
    const ro = new ResizeObserver(fit);
    ro.observe(r);
    fit();

    // damped spring: ~14% overshoot, peak at 0.33 s
    const z = 0.53, wn = 11.1, wd = wn * Math.sqrt(1 - z * z), k = z / Math.sqrt(1 - z * z);
    const sp = (t: number) => (t <= 0 ? 0 : 1 - Math.exp(-z * wn * t) * (Math.cos(wd * t) + k * Math.sin(wd * t)));
    const start = S[Math.max(0, Math.min(2, defaultIndex))];
    let cur = { lens: start.lens, x: [...start.x] };
    const paint = () => {
      const L = cur.lens - 245;
      lens.current!.style.left = rim.current!.style.left = L + "px";
      lens.current!.style.setProperty("--L", L + "px");
      refr.current!.style.left = refr2.current!.style.left = PL - L + "px";
      lc.current!.style.left = L - PL + "px";
      items.current.forEach((el, j) => { if (el) el.style.left = cur.x[j] + "px"; });
    };
    paint();

    let raf = 0;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    // spring from wherever the lens is now, so a click mid-move retargets smoothly
    go.current = (n: number) => {
      items.current.forEach((el, j) => el?.classList.toggle("on", j === n));
      const from = { lens: cur.lens, x: [...cur.x] }, to = S[n];
      cancelAnimationFrame(raf);
      if (reduce) { cur = { lens: to.lens, x: [...to.x] }; paint(); return; }
      const t0 = performance.now();
      const tick = (now: number) => {
        const t = (now - t0) / 1000, p = t > 1.2 ? 1 : sp(t);
        cur = { lens: from.lens + (to.lens - from.lens) * p, x: from.x.map((v, j) => v + (to.x[j] - v) * p) };
        paint();
        if (p !== 1) raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
    };
    return () => { cancelAnimationFrame(raf); ro.disconnect(); };
  }, []);

  return (
    <div ref={root} className={`lgt ${className}`}>
      <style>{CSS}</style>
      <div ref={stage} className="lgt-stage">
        <div className="lgt-bg" />
        <svg width="0" height="0" style={{ position: "absolute" }} aria-hidden="true">
          <defs>
            <mask id="lgt-mA" maskUnits="userSpaceOnUse" x="0" y="0" width="72" height="72">
              <rect width="72" height="72" fill="#fff" />
              <circle cx="61" cy="11" r="14" fill="#000" />
              <polyline points="19,46 30,35 39,43 53,29" fill="none" stroke="#000" strokeWidth="5.5" strokeLinecap="round" strokeLinejoin="round" />
            </mask>
            <mask id="lgt-mB" maskUnits="userSpaceOnUse" x="0" y="0" width="80" height="72">
              <rect width="80" height="72" fill="#fff" />
              <circle cx="30" cy="19" r="22" fill="#000" />
              <rect x="-1" y="42" width="64" height="33" rx="16.5" fill="#000" />
            </mask>
          </defs>
        </svg>

        <div className="pill" />

        <div ref={lens} className="lens">
          <div className="clip">
            <div className="glass see" />
            <div ref={refr} className="refr">
              <div className="wing t" /><div className="body" /><div className="wing b" />
            </div>
            <div className="band t see" />
            <div className="band b see" />
            <div ref={refr2} className="refr">
              <div ref={lc} className="lc"><div className="fr t" /><div className="fr b" /><div className="glow" /></div>
            </div>
          </div>
        </div>

        <button type="button" ref={(el) => { items.current[0] = el; }} className={`item${defaultIndex === 0 ? " on" : ""}`} aria-label={labels[0]} style={{ left: S[defaultIndex]?.x[0] ?? S[0].x[0] }} onClick={() => select(0)}>
          <svg className="ic" viewBox="0 0 68 72" width="68" aria-hidden="true">
            <path fill="currentColor" stroke="currentColor" strokeWidth="10" strokeLinejoin="round" d="M34 6 63 29V67H50V58a11 11 0 0 0-11-11H29a11 11 0 0 0-11 11v9H5V29Z" />
          </svg>
          <span className="lbl">{labels[0]}</span>
        </button>
        <button type="button" ref={(el) => { items.current[1] = el; }} className={`item${defaultIndex === 1 ? " on" : ""}`} aria-label={labels[1]} style={{ left: S[defaultIndex]?.x[1] ?? S[0].x[1] }} onClick={() => select(1)}>
          <svg className="ic" viewBox="0 0 72 72" width="72" aria-hidden="true">
            <rect x="3" y="9" width="60" height="60" rx="22" fill="currentColor" mask="url(#lgt-mA)" />
            <circle cx="61" cy="11" r="8.5" fill="currentColor" />
          </svg>
          <span className="lbl">{labels[1]}</span>
        </button>
        <button type="button" ref={(el) => { items.current[2] = el; }} className={`item${defaultIndex === 2 ? " on" : ""}`} aria-label={labels[2]} style={{ left: S[defaultIndex]?.x[2] ?? S[0].x[2] }} onClick={() => select(2)}>
          <svg className="ic" viewBox="0 0 80 72" width="80" aria-hidden="true">
            <g mask="url(#lgt-mB)" fill="currentColor"><circle cx="55" cy="18" r="14" /><ellipse cx="62" cy="57" rx="16" ry="10.5" /></g>
            <circle cx="30" cy="19" r="17" fill="currentColor" />
            <rect x="4" y="47" width="54" height="23" rx="11.5" fill="currentColor" />
          </svg>
          <span className="lbl">{labels[2]}</span>
        </button>

        <div ref={rim} className="rim" />
      </div>
    </div>
  );
}

export default LiquidGlassTabBar;
