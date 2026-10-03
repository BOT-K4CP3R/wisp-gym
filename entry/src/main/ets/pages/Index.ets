import { AppModel } from '../app/AppModel';
import { CreatureState } from '../core/LifeEngine';
import { CreatureLook } from '../core/CreatureLook';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { StatBar } from '../components/StatBar';

@Entry
@Component
struct Index {
  @State state: CreatureState = new CreatureState();
  @State look: CreatureLook = new CreatureLook();
  @State demo: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    const model = AppModel.get();
    this.demo = model.isDemo();
    const st = await model.state();
    this.state = st;
    this.look = model.lookFor(st);
    model.pushWidget();
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('Wisp Gym')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E8EAF6')
          Blank()
          Text(this.demo ? 'DEMO: simulated sensors' : 'LIVE sensors')
            .fontSize(11)
            .fontColor(this.demo ? '#FFB74D' : '#81C784')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(10)
            .backgroundColor('#2A2C5A')
        }
        .width('100%')
        .margin({ top: 16 })

        CreatureCanvas({ look: this.look, label: '' })

        Text(this.state.headline)
          .fontSize(16)
          .fontColor('#E8EAF6')
          .textAlign(TextAlign.Center)
          .margin({ top: 4, bottom: 12 })

        Row({ space: 10 }) {
          StatBar({ title: 'Train', value: this.state.train, color: '#7C9CFF' })
          StatBar({ title: 'Recover', value: this.state.recover, color: '#66D9A8' })
          StatBar({ title: 'Move', value: this.state.move, color: '#FFB86B' })
        }
        .width('100%')

        Button('Start workout')
          .width('100%')
          .height(52)
          .margin({ top: 18 })
          .backgroundColor('#5C7CFA')
          .fontSize(17)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/Workout' });
          })

        Row({ space: 10 }) {
          Button('Why is Wisp like this?')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#2A2C5A')
            .fontSize(13)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/Why' });
            })
          Button('My week')
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#2A2C5A')
            .fontSize(13)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/Week' });
            })
        }
        .width('100%')
        .margin({ top: 10 })

        Column() {
          Row() {
            Text('Demo mode (simulated sensors)')
              .fontSize(13)
              .fontColor('#C5CAE9')
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.demo })
              .onChange((isOn: boolean) => {
                AppModel.get().setDemo(isOn);
                this.reload();
              })
          }
          .width('100%')
          Row({ space: 8 }) {
            Button('Load 2-week demo history')
              .fontSize(12)
              .height(36)
              .backgroundColor('#34376B')
              .onClick(() => {
                AppModel.get().loadDemoHistory();
                this.message = 'Loaded 14 days of SIMULATED history.';
                this.reload();
              })
            Button('Reset')
              .fontSize(12)
              .height(36)
              .backgroundColor('#34376B')
              .onClick(() => {
                AppModel.get().resetHistory();
                this.message = 'History cleared.';
                this.reload();
              })
          }
          .margin({ top: 8 })
          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(12)
              .fontColor('#9FA8DA')
              .margin({ top: 6 })
          }
          Text('Emulators have no real motion, so Demo mode replays a synthetic accelerometer stream through the same detector as the real sensor.')
            .fontSize(11)
            .fontColor('#7986CB')
            .margin({ top: 8 })
        }
        .padding(12)
        .margin({ top: 18, bottom: 24 })
        .borderRadius(14)
        .backgroundColor('#1F2147')
      }
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#14152E')
    .scrollBar(BarState.Off)
  }
}
