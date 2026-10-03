import { AppModel } from '../app/AppModel';
import { CreatureState, Reason } from '../core/LifeEngine';

@Entry
@Component
struct Why {
  @State state: CreatureState = new CreatureState();

  aboutToAppear(): void {
    AppModel.get().state().then((st: CreatureState) => {
      this.state = st;
    });
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('Back')
            .fontSize(13)
            .height(34)
            .backgroundColor('#2A2C5A')
            .onClick(() => this.getUIContext().getRouter().back())
          Text('Why is Wisp like this?')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E8EAF6')
            .margin({ left: 12 })
        }
        .width('100%')
        .margin({ top: 16, bottom: 8 })

        Text(this.state.headline)
          .fontSize(15)
          .fontColor('#C5CAE9')
          .width('100%')
          .margin({ bottom: 8 })
        Text('Every value below is computed on this phone from your real sessions. Wisp never dies and never loses progress: neglect makes it curious, over-training makes it ask for rest.')
          .fontSize(12)
          .fontColor('#7986CB')
          .width('100%')
          .margin({ bottom: 12 })

        ForEach(this.state.reasons, (r: Reason) => {
          Row() {
            Column() {
              Text(r.label)
                .fontSize(14)
                .fontColor('#E8EAF6')
              Text(r.target)
                .fontSize(11)
                .fontColor('#9FA8DA')
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(r.value)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(r.ok ? '#66D9A8' : '#FFB86B')
          }
          .width('100%')
          .padding(12)
          .margin({ bottom: 8 })
          .borderRadius(12)
          .backgroundColor('#1F2147')
        }, (r: Reason) => r.key)
      }
      .padding({ left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#14152E')
    .scrollBar(BarState.Off)
  }
}
