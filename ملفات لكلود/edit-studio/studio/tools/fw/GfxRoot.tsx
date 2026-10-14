// Template (tools/fw/GfxRoot.tsx): replaces Root.tsx in the temp clone; registers only the Gfx composition.
import {Composition} from 'remotion';
import {Gfx} from './Gfx';

export const /*ROOT*/: React.FC = () => (
  <Composition id="Gfx" component={Gfx} durationInFrames={/*DUR*/} fps={/*FPS*/} width={/*W*/} height={/*H*/}
    defaultProps={{scene: ''}} />
);
