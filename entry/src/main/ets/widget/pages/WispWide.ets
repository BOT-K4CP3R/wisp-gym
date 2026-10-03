import { MiniWisp } from '../common/MiniWisp';

const storage = new LocalStorage();

// 2x4 widget: creature on the left; mood, next step and the three drivers on the right.
@Entry(storage)
@Component
struct WispWide {
  @LocalStorageProp('name') name: string = 'Wisp';
  @LocalStorageProp('moodLabel') moodLabel: string = 'Curious';
  @LocalStorageProp('nextTitle') nextTitle: string = 'Do your first set';
  @LocalStorageProp('eyes') eyes: string = 'open';
  @LocalStorageProp('sparkle') sparkle: boolean = false;
  @LocalStorageProp('hue') hue: string = '#FF8A5B';
  @LocalStorageProp('hueLight') hueLight: string = '#FFC2A3';
  @LocalStorageProp('hueDark') hueDark: string = '#B4502C';
  @LocalStorageProp('legs') legs: number = 1;
  @LocalStorageProp('push') push: number = 1;
  @LocalStorageProp('pull') pull: number = 1;
  @LocalStorageProp('core') core: number = 1;
  @LocalStorageProp('train') train: number = 0;
  @LocalStorageProp('recover') recover: number = 100;
  @LocalStorageProp('move') move: number = 0;
  @LocalStorageProp('steps') steps: string = '0';
  @LocalStorageProp('stepsKnown') stepsKnown: boolean = true;
  @LocalStorageProp('week') week: string = '0/3';
  @LocalStorageProp('demo') demo: boolean = false;

  @Builder
  Metric(label: string, value: string, pct: number, warn: boolean) {
    Column({ space: 3 }) {
      Row() {
        Text(label).fontSize(10).fontColor('#A1A1AA').layoutWeight(1)
        Text(value).fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F4F4F5')
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(4).borderRadius(2).backgroundColor('#26FFFFFF')
        Column()
          .width(Math.max(4, Math.min(100, pct)) + '%')
          .height(4)
          .borderRadius(2)
          .backgroundColor(warn ? '#FF8A5B' : '#F4F4F5')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        MiniWisp({
          scaleBy: 1.0,
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
      .width('38%')
      .height('100%')
      .borderRadius(18)
      .backgroundColor('#1E1F23')

      Column() {
        Row({ space: 6 }) {
          Text(this.name + '  ·  ' + this.moodLabel)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F4F4F5')
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
        Text(this.nextTitle + '  ·  week ' + this.week)
          .fontSize(11)
          .fontColor('#FF8A5B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
        Blank()
        Column({ space: 7 }) {
          this.Metric('Strength', this.train + '%', this.train, false)
          this.Metric('Recovery', this.recover + '%', this.recover, this.recover < 25)
          this.Metric('Steps', this.stepsKnown ? this.steps : 'off', this.move, false)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
      .padding({ top: 2, bottom: 2 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
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
