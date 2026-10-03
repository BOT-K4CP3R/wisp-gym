import { CreatureLook } from '../core/CreatureLook';

// Mutable box shared between a page and its CreatureCanvas. The canvas polls it every
// frame, which avoids relying on @Prop deep-copy semantics for class instances (observed to
// go stale on the OpenHarmony 6.1 runtime: the child kept the first look forever).
export class LookHolder {
  look: CreatureLook = new CreatureLook();
  // Pages set this to false while hidden (covered by another page) so no frames are drawn.
  active: boolean = true;
  // Time of the last tap on the creature (ms); the canvas plays a hop and a heart.
  pokedAt: number = 0;
  // When true the next look is shown at once instead of morphing towards it.
  snap: boolean = true;

  poke(): void {
    this.pokedAt = Date.now();
  }

  set(look: CreatureLook, snap: boolean): void {
    this.look = look;
    this.snap = snap;
  }
}
