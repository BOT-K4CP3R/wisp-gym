import { WidgetCreature } from '../common/WidgetCreature';

const storage = new LocalStorage();

// 2x4 widget: creature on the left; mood, next step and the three drivers on the right.
@Entry(storage)
@Component
struct WispWide {
  @LocalStorageProp('name') name: string = 'Wisp';
  @LocalStorageProp('moodLabel') moodLabel: string = 'Curious';
  @LocalStorageProp('nextTitle') nextTitle: string = 'Do your first set';
  @LocalStorageProp('mood') mood: string = 'curious';
  @LocalStorageProp('hue') hue: number = 24;
  @LocalStorageProp('glow') glow: number = 0.5;
  @LocalStorageProp('eyeOpen') eyeOpen: number = 1;
  @LocalStorageProp('smile') smile: number = 0.55;
  @LocalStorageProp('happyEyes') happyEyes: boolean = false;
  @LocalStorageProp('species') species: string = 'wisp';
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

  private label(key: string): string {
    return key === 'train' ? 'Strength' : (key === 'recover' ? 'Recovery' : 'Steps');
  }

  private valueText(key: string): string {
    if (key === 'train') {
      return this.train + '%';
    }
    if (key === 'recover') {
      return this.recover + '%';
    }
    return this.stepsKnown ? this.steps : 'off';
  }

  private pct(key: string): number {
    return key === 'train' ? this.train : (key === 'recover' ? this.recover : (this.stepsKnown ? this.move : 0));
  }

  // Reads state inside the builder (not via parameters) so updates re-render it.
  @Builder
  Metric(key: string) {
    Column({ space: 3 }) {
      Row() {
        Text(this.label(key)).fontSize(10).fontColor('#A1A1AA').layoutWeight(1)
        Text(this.valueText(key)).fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F4F4F5')
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(4).borderRadius(2).backgroundColor('#26FFFFFF')
        Column()
          .width(Math.max(4, Math.min(100, this.pct(key))) + '%')
          .height(4)
          .borderRadius(2)
          .backgroundColor(key === 'recover' && this.recover < 25 ? '#FF8A5B' : '#F4F4F5')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        WidgetCreature({
          mood: this.mood,
          hue: this.hue,
          glow: this.glow,
          eyeOpen: this.eyeOpen,
          smile: this.smile,
          happyEyes: this.happyEyes,
          species: this.species,
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
        Row({ space: 6 }) {
          Text(this.nextTitle)
            .fontSize(11)
            .fontColor('#FF8A5B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('week ' + this.week)
            .fontSize(10)
            .fontColor('#A1A1AA')
        }
        .width('100%')
        .margin({ top: 2 })
        Blank()
        Column({ space: 7 }) {
          this.Metric('train')
          this.Metric('recover')
          this.Metric('steps')
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
