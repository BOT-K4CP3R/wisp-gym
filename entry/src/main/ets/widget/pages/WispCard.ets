import { MiniWisp } from '../common/MiniWisp';

const storage = new LocalStorage();

// 2x2 widget: the creature, its mood and this week's sessions, like a mood mirror.
@Entry(storage)
@Component
struct WispCard {
  @LocalStorageProp('name') name: string = 'Wisp';
  @LocalStorageProp('moodLabel') moodLabel: string = 'Curious';
  @LocalStorageProp('eyes') eyes: string = 'open';
  @LocalStorageProp('sparkle') sparkle: boolean = false;
  @LocalStorageProp('hue') hue: string = '#FF8A5B';
  @LocalStorageProp('hueLight') hueLight: string = '#FFC2A3';
  @LocalStorageProp('hueDark') hueDark: string = '#B4502C';
  @LocalStorageProp('legs') legs: number = 1;
  @LocalStorageProp('push') push: number = 1;
  @LocalStorageProp('pull') pull: number = 1;
  @LocalStorageProp('core') core: number = 1;
  @LocalStorageProp('moodShort') moodShort: string = 'Ready when you are';
  @LocalStorageProp('weekDone') weekDone: number = 0;
  @LocalStorageProp('weekGoal') weekGoal: number = 3;
  @LocalStorageProp('demo') demo: boolean = false;

  // One segment per planned session this week; filled = done.
  private dots(): boolean[] {
    const out: boolean[] = [];
    const n = Math.max(1, Math.min(7, this.weekGoal));
    for (let i = 0; i < n; i++) {
      out.push(i < this.weekDone);
    }
    return out;
  }

  build() {
    Column() {
      Row() {
        Text(this.name)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#A1A1AA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.demo) {
          Text('DEMO')
            .fontSize(8)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF8A5B')
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('#26FF8A5B')
        }
      }
      .width('100%')

      Stack() {
        MiniWisp({
          scaleBy: 0.74,
          eyes: this.eyes,
          sparkle: this.sparkle,
          hue: this.hue,
          hueLight: this.hueLight,
          hueDark: this.hueDark,
          legs: this.legs,
          push: this.push,
          pull: this.pull,
          core: this.core
        })
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)

      Text(this.moodLabel)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F4F4F5')
        .maxLines(1)
        .width('100%')
      Row({ space: 3 }) {
        ForEach(this.dots(), (on: boolean, i: number) => {
          Column()
            .layoutWeight(1)
            .height(4)
            .borderRadius(2)
            .backgroundColor(on ? '#FF8A5B' : '#26FFFFFF')
        }, (on: boolean, i: number) => i + (on ? 'a' : 'b'))
        Text(this.weekDone + '/' + this.weekGoal)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#A1A1AA')
          .margin({ left: 4 })
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 10, bottom: 12, left: 12, right: 12 })
    .backgroundColor('#151619')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        moduleName: 'entry',
        abilityName: 'EntryAbility',
        params: { target: 'home' }
      });
    })
  }
}
