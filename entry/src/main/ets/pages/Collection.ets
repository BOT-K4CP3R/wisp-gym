import { AppModel } from '../app/AppModel';
import { Achievement } from '../core/Achievements';
import { CreatureLook } from '../core/CreatureLook';
import { CreatureState } from '../core/LifeEngine';
import { SPECIES, Species, findSpecies } from '../core/Species';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { IconButton, Reveal, SectionLabel, Tag, Tile } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { press } from '../ui/Motion';
import { dayLabel } from '../core/Plan';
import {
  ACCENT, ACCENT_TINT, BG, F_BOLD, F_REG, GAP, HAIRLINE, PAD, STAGGER, SURFACE, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_BORDER
} from '../ui/Theme';

class Slot {
  species: Species;
  unlocked: boolean;
  hint: string;
  holder: LookHolder;

  constructor(species: Species, unlocked: boolean, hint: string, holder: LookHolder) {
    this.species = species;
    this.unlocked = unlocked;
    this.hint = hint;
    this.holder = holder;
  }
}

function badgeIcon(icon: string): Resource {
  if (icon === 'trophy') {
    return $r('app.media.ic_trophy_accent');
  }
  if (icon === 'moon') {
    return $r('app.media.ic_moon_accent');
  }
  if (icon === 'steps') {
    return $r('app.media.ic_steps_accent');
  }
  if (icon === 'sparkle') {
    return $r('app.media.ic_sparkle_accent');
  }
  if (icon === 'heart') {
    return $r('app.media.ic_heart_accent');
  }
  if (icon === 'target') {
    return $r('app.media.ic_target_accent');
  }
  if (icon === 'phone') {
    return $r('app.media.ic_phone_accent');
  }
  return $r('app.media.ic_bolt_accent');
}

// Creatures to raise and badges to earn. Unlocked creatures can be switched at any time:
// progress belongs to the training history, not to the creature.
@Entry
@Component
struct Collection {
  @State slots: Slot[] = [];
  @State badges: Achievement[] = [];
  @State current: string = 'wisp';
  @State unlockedCount: number = 0;
  @State badgeCount: number = 0;

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    this.load();
  }

  onPageShow(): void {
    for (let i = 0; i < this.slots.length; i++) {
      this.slots[i].holder.active = true;
    }
  }

  onPageHide(): void {
    for (let i = 0; i < this.slots.length; i++) {
      this.slots[i].holder.active = false;
    }
  }

  private load(): void {
    const model = AppModel.get();
    this.current = model.profile().species;
    const badges = model.achievements();
    const open = model.unlockedSpecies();
    const st: CreatureState = model.evaluateNow();
    const out: Slot[] = [];
    for (let i = 0; i < SPECIES.length; i++) {
      const sp = SPECIES[i];
      const holder = new LookHolder();
      const unlocked = open.indexOf(sp.id) >= 0;
      let look: CreatureLook;
      if (unlocked) {
        look = model.lookForSpecies(st, sp.id);
        look.expression = sp.id === this.current ? 'joy' : 'happy';  // show them at their best
      } else {
        look = new CreatureLook();
        look.species = sp.id;
        look.hue = sp.hueBase;
        look.expression = 'asleep';  // still in its egg-nap until unlocked
      }
      holder.set(look, true);
      let hint = '';
      if (!unlocked) {
        for (let k = 0; k < badges.length; k++) {
          if (badges[k].id === sp.unlock) {
            hint = 'Earn "' + badges[k].title + '"';
          }
        }
      }
      out.push(new Slot(sp, unlocked, hint, holder));
    }
    this.slots = out;
    this.badges = badges;
    this.unlockedCount = open.length;
    let n = 0;
    for (let i = 0; i < badges.length; i++) {
      if (badges[i].unlocked) {
        n++;
      }
    }
    this.badgeCount = n;
  }

  private rows(): number[] {
    const out: number[] = [];
    for (let i = 0; i < Math.ceil(this.slots.length / 2); i++) {
      out.push(i);
    }
    return out;
  }

  private choose(slot: Slot): void {
    if (!slot.unlocked) {
      slot.holder.express('curious', 900);
      AppModel.get().tick(10);
      this.toast(slot.hint.length > 0 ? slot.hint + ' to hatch ' + slot.species.name + '.' : 'Keep training to hatch it.');
      return;
    }
    if (slot.species.id === this.current) {
      slot.holder.poke();
      return;
    }
    const model = AppModel.get();
    const p = model.profile();
    const oldName = p.name;
    // Keep a custom name; follow the species only while the creature has its species' name.
    const followName = oldName === findSpecies(p.species).name;
    p.species = slot.species.id;
    if (followName) {
      p.name = slot.species.name;
    }
    model.saveProfile(p);
    this.current = slot.species.id;
    slot.holder.poke();
    slot.holder.express('joy', 1200);
    model.tick(30);
    this.toast(p.name + ' is now your training buddy');
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (e) {
      // cosmetic
    }
  }

  @Builder
  SlotTile(slot: Slot) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          CreatureCanvas({ holder: slot.holder, label: '', canvasHeight: 112, tappable: false, still: true,
            a11y: slot.species.name + (slot.unlocked ? '' : ', not hatched yet') })
        }
        .width('100%')
        .opacity(slot.unlocked ? 1 : 0.35)
        if (!slot.unlocked) {
          Image($r('app.media.ic_lock')).width(18).height(18).margin({ top: 4, right: 4 })
        }
      }
      .width('100%')
      Row({ space: 6 }) {
        Text(slot.species.name)
          .fontSize(16)
          .fontFamily(F_BOLD)
          .fontColor(slot.unlocked ? TEXT : TEXT_DIM)
        if (slot.unlocked && slot.species.id === this.current) {
          Tag({ text: 'YOURS', accent: true })
        }
      }
      .margin({ top: 4 })
      Text(slot.unlocked ? slot.species.blurb : slot.hint)
        .fontSize(11)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
        .constraintSize({ minHeight: 44 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(24)
    .backgroundColor(slot.species.id === this.current ? ACCENT_TINT : SURFACE)
    .border({ width: 1, color: slot.species.id === this.current ? ACCENT_BORDER : HAIRLINE })
    .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.96 }))
    .accessibilityText(slot.species.name + (slot.unlocked ? '' : ', locked. ' + slot.hint))
    .onClick(() => this.choose(slot))
  }

  @Builder
  BadgeRow(b: Achievement, last: boolean) {
    Column() {
      Row({ space: 14 }) {
        Image(badgeIcon(b.icon))
          .width(40)
          .height(40)
          .padding(10)
          .borderRadius(20)
          .backgroundColor(b.unlocked ? ACCENT_TINT : TRACK)
          .opacity(b.unlocked ? 1 : 0.45)
        Column({ space: 4 }) {
          Row() {
            Text(b.title)
              .fontSize(15)
              .fontFamily(F_BOLD)
              .fontColor(b.unlocked ? TEXT : TEXT_DIM)
              .layoutWeight(1)
            Text(b.unlocked ? (b.unlockedAt > 0 ? dayLabel(b.unlockedAt, Date.now()) : 'Earned') :
              Math.min(b.progress, b.goal) + '/' + b.goal)
              .fontSize(12)
              .fontFamily(F_BOLD)
              .fontColor(b.unlocked ? ACCENT : TEXT_MUTE)
          }
          .width('100%')
          Text(b.detail).fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE).width('100%')
          if (!b.unlocked && b.goal > 1) {
            Progress({ value: Math.round(100 * Math.min(b.progress, b.goal) / b.goal), total: 100, type: ProgressType.Linear })
              .width('100%')
              .color(ACCENT)
              .backgroundColor(TRACK)
              .style({ strokeWidth: 4, strokeRadius: 2, enableSmoothEffect: false })
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Top)
      if (!last) {
        Divider().color(HAIRLINE).strokeWidth(1).margin({ left: 54 })
      }
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        IconButton({ icon: $r('app.media.ic_back'), label: 'Back', onTap: () => this.getUIContext().getRouter().back() })
        Column() {
          Text('Collection').fontSize(22).fontFamily(F_BOLD).fontColor(TEXT)
          Text(this.unlockedCount + ' of ' + SPECIES.length + ' creatures  ·  ' + this.badgeCount + ' of ' +
            this.badges.length + ' badges')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          SectionLabel({ text: 'Creatures' })
          ForEach(this.rows(), (r: number) => {
            Row({ space: GAP }) {
              Column() {
                this.SlotTile(this.slots[r * 2])
              }
              .layoutWeight(1)
              if (r * 2 + 1 < this.slots.length) {
                Column() {
                  this.SlotTile(this.slots[r * 2 + 1])
                }
                .layoutWeight(1)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (r: number) => 'row' + r + this.current + this.unlockedCount)

          Text('Your progress belongs to your training, not to one creature: switch any time.')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
            .width('100%')
            .padding({ left: 4 })

          SectionLabel({ text: 'Badges' })
          Reveal({ delay: STAGGER }) {
            Tile({ pad: 6 }) {
              Column() {
                ForEach(this.badges, (b: Achievement, i: number) => {
                  this.BadgeRow(b, i === this.badges.length - 1)
                }, (b: Achievement) => b.id + (b.unlocked ? '1' : '0') + b.progress)
              }
              .padding({ left: 14, right: 14 })
            }
          }
          Blank().height(24)
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
