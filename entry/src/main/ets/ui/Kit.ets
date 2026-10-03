import { ACCENT, ACCENT_LOW, ACCENT_MID, F_BOLD, F_REG, HAIRLINE, ON_ACCENT, R_PILL, R_TILE, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE, TRACK } from './Theme';

@Builder
function noContent() {
}

// Bordered charcoal tile.
@Component
export struct Tile {
  @BuilderParam content: () => void = noContent;
  @Prop pad: number = 20;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.pad)
    .borderRadius(R_TILE)
    .backgroundColor(SURFACE)
    .border({ width: 1, color: HAIRLINE })
  }
}

// Round bordered icon button.
@Component
export struct IconButton {
  @Prop icon: Resource = $r('app.media.ic_close');
  @Prop label: string = '';
  onTap: () => void = () => {};
  @State pressed: boolean = false;

  build() {
    Image(this.icon)
      .width(48)
      .height(48)
      .padding(13)
      .borderRadius(24)
      .backgroundColor(this.pressed ? SURFACE_HI : SURFACE)
      .border({ width: 1, color: HAIRLINE })
      .accessibilityText(this.label)
      .onTouch((e: TouchEvent) => {
        this.pressed = e.type === TouchType.Down || e.type === TouchType.Move;
      })
      .onClick(() => this.onTap())
  }
}

// Pill button. primary = accent fill, otherwise a raised charcoal surface.
@Component
export struct Button56 {
  @Prop label: string = '';
  @Prop primary: boolean = true;
  onTap: () => void = () => {};
  @State pressed: boolean = false;

  build() {
    Text(this.label)
      .fontSize(17)
      .fontFamily(F_BOLD)
      .fontColor(this.primary ? ON_ACCENT : TEXT)
      .width('100%')
      .height(56)
      .textAlign(TextAlign.Center)
      .borderRadius(R_PILL)
      .backgroundColor(this.primary ? ACCENT : SURFACE_HI)
      .border({ width: this.primary ? 0 : 1, color: HAIRLINE })
      .opacity(this.pressed ? 0.85 : 1)
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        this.pressed = e.type === TouchType.Down || e.type === TouchType.Move;
      })
      .onClick(() => this.onTap())
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
      Text(this.subtitle)
        .fontSize(12)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .maxLines(1)
        .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Start)
  }
}

// Thin ring with the number inside, like the reference's workout tile.
@Component
export struct RingNumber {
  @Prop value: number = 0;       // 0..1
  @Prop diameter: number = 64;

  build() {
    Stack() {
      Progress({ value: Math.round(this.value * 100), total: 100, type: ProgressType.Ring })
        .width(this.diameter)
        .height(this.diameter)
        .color(ACCENT)
        .backgroundColor(TRACK)
        .style({ strokeWidth: 4 })
      Text(Math.round(this.value * 100) + '')
        .fontSize(this.diameter * 0.34)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
    }
  }
}

// Dot-matrix calendar: 7 columns, oldest day first. Brighter dot = more reps that day.
@Component
export struct ActivityDots {
  @Prop values: number[] = [];

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

  build() {
    Column({ space: 8 }) {
      ForEach(this.rows(), (r: number) => {
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
            Circle()
              .width(this.values[r * 7 + c] > 0 ? 12 : 8)
              .height(this.values[r * 7 + c] > 0 ? 12 : 8)
              .fill(this.dotColor(this.values[r * 7 + c] === undefined ? 0 : this.values[r * 7 + c]))
              .layoutWeight(0)
            Blank().width(0)
          }, (c: number) => '' + r + '-' + c)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .height(12)
      }, (r: number) => '' + r)
    }
    .width('100%')
  }
}

// Label left, value right (the reference's "Information" rows).
@Component
export struct InfoRow {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop divider: boolean = true;
  @Prop strong: boolean = false;

  build() {
    Column() {
      Row() {
        Text(this.label)
          .fontSize(15)
          .fontFamily(F_REG)
          .fontColor(TEXT_DIM)
          .layoutWeight(1)
        Text(this.value)
          .fontSize(15)
          .fontFamily(F_BOLD)
          .fontColor(this.strong ? ACCENT : TEXT)
      }
      .width('100%')
      .height(52)
      if (this.divider) {
        Divider().color(HAIRLINE).strokeWidth(1)
      }
    }
  }
}

@Component
export struct Tag {
  @Prop text: string = '';

  build() {
    Text(this.text)
      .fontSize(11)
      .fontFamily(F_BOLD)
      .fontColor(TEXT_DIM)
      .letterSpacing(0.5)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(10)
      .backgroundColor(SURFACE_HI)
  }
}

// Floating bottom tab bar: Wisp / Week / [Train] / Insights.
@Component
export struct TabBar {
  @Prop active: string = 'home';
  onNavigate: (target: string) => void = () => {};

  @Builder
  Item(id: string, icon: Resource) {
    Image(icon)
      .width(48)
      .height(48)
      .padding(13)
      .borderRadius(24)
      .backgroundColor(this.active === id ? SURFACE_HI : '#00000000')
      .opacity(this.active === id ? 1 : 0.5)
      .onClick(() => this.onNavigate(id))
  }

  build() {
    Row() {
      this.Item('home', $r('app.media.ic_home'))
      this.Item('week', $r('app.media.ic_calendar'))
      Image($r('app.media.ic_dumbbell_dark'))
        .width(52)
        .height(52)
        .padding(14)
        .borderRadius(26)
        .backgroundColor(ACCENT)
        .onClick(() => this.onNavigate('train'))
      this.Item('why', $r('app.media.ic_bars'))
    }
    .width('100%')
    .height(72)
    .padding({ left: 14, right: 14 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .borderRadius(36)
    .backgroundColor(SURFACE)
    .border({ width: 1, color: HAIRLINE })
  }
}
