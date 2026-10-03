const storage = new LocalStorage();

@Entry(storage)
@Component
struct WispCard {
  @LocalStorageProp('mood') mood: string = 'curious';
  @LocalStorageProp('headline') headline: string = 'Open Wisp Gym';
  @LocalStorageProp('hue') hue: string = '#4F8CFF';
  @LocalStorageProp('legs') legs: number = 1;
  @LocalStorageProp('push') push: number = 1;
  @LocalStorageProp('pull') pull: number = 1;
  @LocalStorageProp('core') core: number = 1;
  @LocalStorageProp('train') train: number = 0;
  @LocalStorageProp('recover') recover: number = 100;
  @LocalStorageProp('move') move: number = 0;
  @LocalStorageProp('demo') demo: boolean = false;

  build() {
    Row() {
      // Creature built from plain rounded boxes (cards cannot host a Canvas).
      Stack() {
        Column() {
          Row()
            .width(30 * this.push)
            .height(26)
            .backgroundColor(this.hue)
            .borderRadius(13)
            .margin({ bottom: -4 })
          Column() {
            Row() {
              Circle().width(7).height(this.mood === 'resting' ? 2 : 7).fill('#1B1B2F')
              Circle().width(7).height(this.mood === 'resting' ? 2 : 7).fill('#1B1B2F').margin({ left: 12 })
            }
          }
          .width(40 * this.core)
          .height(46 * this.core)
          .backgroundColor(this.hue)
          .borderRadius(22)
          .justifyContent(FlexAlign.Center)
          Row() {
            Row().width(12 * this.legs).height(18 * this.legs).backgroundColor(this.hue).borderRadius(6)
            Row().width(12 * this.legs).height(18 * this.legs).backgroundColor(this.hue).borderRadius(6).margin({ left: 6 })
          }
          .margin({ top: -4 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('42%')
      .height('100%')

      Column() {
        Text(this.headline)
          .fontSize(12)
          .fontColor('#E8EAF6')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text('Train ' + this.train + '%  Rec ' + this.recover + '%')
          .fontSize(10)
          .fontColor('#9FA8DA')
        Text(this.demo ? 'DEMO data' : 'Live data')
          .fontSize(9)
          .fontColor(this.demo ? '#FFB74D' : '#81C784')
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 6 })
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor('#1A1B3A')
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
