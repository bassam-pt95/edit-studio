// Template (tools/fw/Gfx.tsx, SPEC-v2 §29.9): one scene of the work folder alone on a transparent 1080×1920 frame, at
// timeline frame `frame`. from-work.mjs copies it into a temp clone of <work>/remotion/src and fills the /*…*/ slots.
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {GfxScene} from './GfxScenes';
/*IMPORTS*/

export const Gfx: React.FC<{scene: string}> = ({scene}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = /*TIME*/;
  return <AbsoluteFill style={/*STYLE*/}><GfxScene scene={scene} t={t}/></AbsoluteFill>;
};
