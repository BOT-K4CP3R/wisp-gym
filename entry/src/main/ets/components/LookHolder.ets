import { CreatureLook } from '../core/CreatureLook';

// Mutable box shared between a page and its CreatureCanvas. The canvas polls it every
// frame, which avoids relying on @Prop deep-copy semantics for class instances (observed to
// go stale on the OpenHarmony 6.1 runtime: the child kept the first look forever).
export class LookHolder {
  look: CreatureLook = new CreatureLook();
  // Pages set this to false while hidden (covered by another page) so no frames are drawn.
  active: boolean = true;
}
