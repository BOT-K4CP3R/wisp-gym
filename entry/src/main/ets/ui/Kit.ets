import {
  ACCENT, ACCENT_LOW, ACCENT_MID, ACCENT_TINT, DANGER, DUR_FAST, DUR_SLOW, F_BOLD, F_REG, HAIRLINE, ON_ACCENT, R_PILL, R_TILE, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_BORDER
} from './Theme';
import { anim, fx, press, motionOn } from './Motion';

@Builder
function noContent() {
}

// Bordered charcoal tile. Tappable tiles get a press-scale effect.
@Component
export struct Tile {
  @BuilderParam content: () => void = noContent;
  @Prop pad: number = 20;
  @Prop highlight: boolean = false;
  @Prop tappable: boolean = false;
  onTap: () => void = () => {};

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(this.pad)
    .borderRadius(R_TILE)
    .backgroundColor(this.highlight ? ACCENT_TINT : SURFACE)
    .border({ width: 1, color: this.highlight ? ACCENT_BORDER : HAIRLINE })
    .clickEffect(this.tappable ? press({ level: ClickEffectLevel.LIGHT, scale: 0.97 }) : null)
    .onClick(() => {
      if (this.tappable) {
        this.onTap();
      }
    })
  }
}

// Fades and lifts its content in when it is inserted; `delay` staggers a list of tiles.
// Implemented as an appear transition, so content is never left invisible if the
// animation cannot run (slow device, reduced motion): the end state is the default state.
@Component
export struct Reveal {
  @BuilderParam content: () => void = noContent;
  @Prop delay: number = 0;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .transition(fx(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 18 }))
      .animation(anim({ duration: DUR_SLOW, delay: this.delay, curve: Curve.Friction }))))
  }
}

// Round bordered icon button.
@Component
export struct IconButton {
  @Prop icon: Resource = $r('app.media.ic_close');
  @Prop label: string = '';
  @Prop diameter: number = 48;
  @Prop filled: boolean = false;
  onTap: () => void = () => {};

  build() {
    Image(this.icon)
      .width(this.diameter)
      .height(this.diameter)
      .padding(this.diameter * 0.27)
      .borderRadius(this.diameter / 2)
      .backgroundColor(this.filled ? ACCENT : SURFACE)
      .border({ width: this.filled ? 0 : 1, color: HAIRLINE })
      .accessibilityText(this.label)
      .clickEffect(press({ level: ClickEffectLevel.MIDDLE, scale: 0.9 }))
      .onClick(() => this.onTap())
  }
}

// Pill button. kind: primary (accent fill), secondary (raised surface), ghost (text only), danger.
@Component
export struct Button56 {
  @Prop label: string = '';
  @Prop primary: boolean = true;
  @Prop kind: string = '';
  @Prop active: boolean = true;
  @Prop height56: number = 56;
  onTap: () => void = () => {};

  private k(): string {
    return this.kind.length > 0 ? this.kind : (this.primary ? 'primary' : 'secondary');
  }

  private fg(): string {
    const k = this.k();
    if (k === 'primary') {
      return ON_ACCENT;
    }
    if (k === 'danger') {
      return DANGER;
    }
    if (k === 'ghost') {
      return TEXT_DIM;
    }
    return TEXT;
  }

  private bg(): string {
    const k = this.k();
    if (k === 'primary') {
      return ACCENT;
    }
    if (k === 'ghost') {
      return '#00000000';
    }
    return SURFACE_HI;
  }

  build() {
    Text(this.label)
      .fontSize(17)
      .fontFamily(F_BOLD)
      .fontColor(this.fg())
      .width('100%')
      .height(this.height56)
      .textAlign(TextAlign.Center)
      .borderRadius(R_PILL)
      .backgroundColor(this.bg())
      .border({ width: this.k() === 'secondary' || this.k() === 'danger' ? 1 : 0, color: HAIRLINE })
      .opacity(this.active ? 1 : 0.4)
      .accessibilityText(this.label)
      .clickEffect(this.active ? press({ level: ClickEffectLevel.LIGHT, scale: 0.96 }) : null)
      .onClick(() => {
        if (this.active) {
          this.onTap();
        }
      })
  }
}

// Title + subtitle pair used at the bottom of tiles.
@Component
export struct TitleBlock {
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.subtitle)
        .fontSize(12)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
  }
}

// Section label above a group of tiles.
@Component
export struct SectionLabel {
  @Prop text: string = '';

  build() {
    Text(this.text.toUpperCase())
      .fontSize(12)
      .fontFamily(F_BOLD)
      .fontColor(TEXT_MUTE)
      .letterSpacing(1)
      .width('100%')
      .padding({ left: 4 })
      .margin({ top: 12, bottom: 2 })
  }
}

// Thin ring with the number inside. Progress animates smoothly between values.
@Component
export struct RingNumber {
  @Prop value: number = 0;       // 0..1
  @Prop diameter: number = 64;
  @Prop text: string = '';       // defaults to the percentage
  @Prop color: string = ACCENT;
  @Prop stroke: number = 5;

  build() {
    Stack() {
      Progress({ value: Math.round(this.value * 100), total: 100, type: ProgressType.Ring })
        .width(this.diameter)
        .height(this.diameter)
        .color(this.color)
        .backgroundColor(TRACK)
        .style({ strokeWidth: this.stroke, enableSmoothEffect: motionOn() })
      Text(this.text.length > 0 ? this.text : '' + Math.round(this.value * 100))
        .fontSize(this.diameter * 0.32)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
    }
  }
}

// Labelled horizontal bar, e.g. a muscle group level.
@Component
export struct MetricBar {
  @Prop label: string = '';
  @Prop value: number = 0;      // 0..1
  @Prop valueText: string = '';
  @Prop color: string = TEXT;
  @Prop delay: number = 0;

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.label).fontSize(14).fontFamily(F_REG).fontColor(TEXT_DIM).layoutWeight(1)
        Text(this.valueText.length > 0 ? this.valueText : Math.round(this.value * 100) + '%')
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(6).borderRadius(3).backgroundColor(TRACK)
        Column()
          .width((Math.max(0.02, Math.min(1, this.value)) * 100).toFixed(1) + '%')
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.color)
          .animation(anim({ duration: DUR_SLOW + 200, delay: this.delay, curve: Curve.Friction }))
      }
      .width('100%')
    }
    .width('100%')
  }
}

// Dot-matrix calendar: 7 columns (Monday first), oldest week on top. Brighter = more reps.
@Component
export struct ActivityDots {
  @Prop values: number[] = [];    // oldest first, length a multiple of 7, last = today
  @Prop todayIndex: number = -1;  // index of today inside `values`

  private dotColor(v: number): string {
    if (v <= 0) {
      return TRACK;
    }
    if (v < 12) {
      return ACCENT_LOW;
    }
    if (v < 30) {
      return ACCENT_MID;
    }
    return ACCENT;
  }

  private rows(): number[] {
    const out: number[] = [];
    const n = Math.ceil(this.values.length / 7);
    for (let i = 0; i < n; i++) {
      out.push(i);
    }
    return out;
  }

  private val(i: number): number {
    const v = this.values[i];
    return v === undefined ? -1 : v;
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        ForEach(['M', 'T', 'W', 'T', 'F', 'S', 'S'], (d: string, i: number) => {
          Text(d)
            .fontSize(10)
            .fontFamily(F_BOLD)
            .fontColor(TEXT_MUTE)
            .width(14)
            .textAlign(TextAlign.Center)
        }, (d: string, i: number) => 'h' + i)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      ForEach(this.rows(), (r: number) => {
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
            Stack() {
              if (this.val(r * 7 + c) >= 0) {
                Circle()
                  .width(this.val(r * 7 + c) > 0 ? 12 : 8)
                  .height(this.val(r * 7 + c) > 0 ? 12 : 8)
                  .fill(this.dotColor(this.val(r * 7 + c)))
              }
              if (r * 7 + c === this.todayIndex) {
                Circle().width(18).height(18).fill('#00000000').stroke(TEXT_DIM).strokeWidth(1.5)
              }
            }
            .width(14)
            .height(18)
          }, (c: number) => '' + r + '-' + c)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }, (r: number) => '' + r)
    }
    .width('100%')
  }
}

// Label left, value right.
@Component
export struct InfoRow {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop divider: boolean = true;
  @Prop strong: boolean = false;
  @Prop sub: string = '';

  build() {
    Column() {
      Row({ space: 12 }) {
        Column() {
          Text(this.label)
            .fontSize(15)
            .fontFamily(F_REG)
            .fontColor(TEXT_DIM)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.sub.length > 0) {
            Text(this.sub)
              .fontSize(12)
              .fontFamily(F_REG)
              .fontColor(TEXT_MUTE)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.value)
          .fontSize(15)
          .fontFamily(F_BOLD)
          .fontColor(this.strong ? ACCENT : TEXT)
          .maxLines(1)
      }
      .width('100%')
      .constraintSize({ minHeight: 52 })
      .padding({ top: 8, bottom: 8 })
      if (this.divider) {
        Divider().color(HAIRLINE).strokeWidth(1)
      }
    }
  }
}

@Component
export struct Tag {
  @Prop text: string = '';
  @Prop accent: boolean = false;

  build() {
    Text(this.text)
      .fontSize(11)
      .fontFamily(F_BOLD)
      .fontColor(this.accent ? ACCENT : TEXT_DIM)
      .letterSpacing(0.5)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(10)
      .backgroundColor(this.accent ? ACCENT_TINT : SURFACE_HI)
  }
}

// Selectable chip (segmented choices in onboarding and settings).
@Component
export struct Chip {
  @Prop text: string = '';
  @Prop selected: boolean = false;
  @Prop grow: boolean = false;
  onTap: () => void = () => {};

  build() {
    Text(this.text)
      .fontSize(15)
      .fontFamily(F_BOLD)
      .fontColor(this.selected ? ON_ACCENT : TEXT)
      .textAlign(TextAlign.Center)
      .height(48)
      .padding({ left: 16, right: 16 })
      .borderRadius(24)
      .backgroundColor(this.selected ? ACCENT : SURFACE_HI)
      .border({ width: this.selected ? 0 : 1, color: HAIRLINE })
      .layoutWeight(this.grow ? 1 : 0)
      .animation(anim({ duration: DUR_FAST, curve: Curve.EaseOut }))
      .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.94 }))
      .accessibilityText(this.text + (this.selected ? ', selected' : ''))
      .onClick(() => this.onTap())
  }
}

// Settings-style row with an icon, a title, an optional value and a chevron.
@Component
export struct NavRow {
  @Prop icon: Resource = $r('app.media.ic_chevron');
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop danger: boolean = false;
  @Prop divider: boolean = true;
  @Prop chevron: boolean = true;
  @Prop tappable: boolean = true;
  onTap: () => void = () => {};

  build() {
    Column() {
      Row({ space: 14 }) {
        Image(this.icon).width(22).height(22).opacity(this.danger ? 1 : 0.85)
        Text(this.title)
          .fontSize(16)
          .fontFamily(F_BOLD)
          .fontColor(this.danger ? DANGER : TEXT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.value.length > 0) {
          Text(this.value).fontSize(15).fontFamily(F_REG).fontColor(TEXT_DIM).maxLines(1)
        }
        if (this.chevron) {
          Image($r('app.media.ic_chevron')).width(18).height(18).opacity(0.4)
        }
      }
      .width('100%')
      .height(56)
      if (this.divider) {
        Divider().color(HAIRLINE).strokeWidth(1).margin({ left: 36 })
      }
    }
    .clickEffect(this.tappable ? press({ level: ClickEffectLevel.LIGHT, scale: 0.98 }) : null)
    .onClick(() => {
      if (this.tappable) {
        this.onTap();
      }
    })
  }
}

// Floating bottom tab bar: Home / Progress / [Train] / Insights.
@Component
export struct TabBar {
  @Prop active: string = 'home';
  onNavigate: (target: string) => void = () => {};

  @Builder
  Item(id: string, icon: Resource, label: string) {
    Column({ space: 3 }) {
      Image(icon).width(22).height(22)
      Text(label).fontSize(10).fontFamily(F_BOLD).fontColor(TEXT)
    }
    .width(68)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .borderRadius(20)
    .backgroundColor(this.active === id ? SURFACE_HI : '#00000000')
    .opacity(this.active === id ? 1 : 0.55)
    .animation(anim({ duration: DUR_FAST, curve: Curve.EaseOut }))
    .accessibilityText(label)
    .accessibilitySelected(this.active === id)
    .onClick(() => this.onNavigate(id))
  }

  build() {
    Row() {
      this.Item('home', $r('app.media.ic_home'), 'Home')
      this.Item('progress', $r('app.media.ic_calendar'), 'Progress')
      Image($r('app.media.ic_dumbbell_dark'))
        .width(56)
        .height(56)
        .padding(15)
        .borderRadius(28)
        .backgroundColor(ACCENT)
        .accessibilityText('Start workout')
        .clickEffect(press({ level: ClickEffectLevel.MIDDLE, scale: 0.9 }))
        .onClick(() => this.onNavigate('train'))
      this.Item('insights', $r('app.media.ic_bars'), 'Insights')
    }
    .width('100%')
    .height(72)
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .borderRadius(36)
    .backgroundColor(SURFACE)
    .border({ width: 1, color: HAIRLINE })
    .shadow({ radius: 24, color: '#99000000', offsetY: 6 })
  }
}

// Centered empty-state message with an icon.
@Component
export struct EmptyState {
  @Prop icon: Resource = $r('app.media.ic_sparkle');
  @Prop title: string = '';
  @Prop detail: string = '';

  build() {
    Column({ space: 8 }) {
      Image(this.icon).width(28).height(28).opacity(0.7)
      Text(this.title).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).textAlign(TextAlign.Center)
      Text(this.detail).fontSize(13).fontFamily(F_REG).fontColor(TEXT_MUTE).textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}

