const storage = new LocalStorage();

@Entry(storage)
@Component
struct WispCard {
  @LocalStorageProp('mood') mood: string = 'curious';
  @LocalStorageProp('headline') headline: string = 'Open Wisp Gym';
  @LocalStorageProp('moodLabel') moodLabel: string = 'Curious';
  @LocalStorageProp('hue') hue: string = '#4F8CFF';
  @LocalStorageProp('hueLight') hueLight: string = '#A9C4FF';
  @LocalStorageProp('hueDark') hueDark: string = '#2F5FCC';
  @LocalStorageProp('legs') legs: number = 1;
  @LocalStorageProp('push') push: number = 1;
  @LocalStorageProp('pull') pull: number = 1;
  @LocalStorageProp('core') core: number = 1;
  @LocalStorageProp('train') train: number = 0;
  @LocalStorageProp('recover') recover: number = 100;
  @LocalStorageProp('move') move: number = 0;
  @LocalStorageProp('demo') demo: boolean = false;

  // Plush creature from rounded boxes and gradients (cards cannot host a Canvas).
  @Builder
  MiniWisp() {
    Stack({ alignContent: Alignment.TopStart }) {
      // tuft
      Column()
        .width(11)
        .height(22)
        .borderRadius(8)
        .linearGradient({ angle: 180, colors: [['#FFF3B0', 0.0], [this.hueLight, 1.0]] })
        .position({ x: 36, y: 0 })
        .rotate({ angle: 10 })
      // feet
      Column()
        .width(20 * this.legs)
        .height(12 * this.legs)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 14, y: 84 })
      Column()
        .width(20 * this.legs)
        .height(12 * this.legs)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 48, y: 84 })
      // arms
      Column()
        .width(12 * this.pull)
        .height(32 * this.pull)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 2, y: 46 })
        .rotate({ angle: 18 })
      Column()
        .width(12 * this.pull)
        .height(32 * this.pull)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 68, y: 46 })
        .rotate({ angle: -18 })
      // torso
      Column()
        .width(56 * this.core)
        .height(52 * this.core)
        .borderRadius(28)
        .linearGradient({ angle: 160, colors: [[this.hueLight, 0.0], [this.hue, 0.6], [this.hueDark, 1.0]] })
        .position({ x: 40 - 28 * this.core, y: 54 })
      Column()
        .width(30 * this.core)
        .height(28 * this.core)
        .borderRadius(16)
        .backgroundColor('#66FFFFFF')
        .position({ x: 40 - 15 * this.core, y: 66 })
      // head
      Column()
        .width(52)
        .height(46)
        .borderRadius(26)
        .linearGradient({ angle: 160, colors: [[this.hueLight, 0.0], [this.hue, 1.0]] })
        .position({ x: 14, y: 18 })
      // cheeks
      Column().width(9).height(6).borderRadius(4).backgroundColor('#66FF6E96').position({ x: 18, y: 46 })
      Column().width(9).height(6).borderRadius(4).backgroundColor('#66FF6E96').position({ x: 53, y: 46 })
      // eyes
      Column()
        .width(11)
        .height(this.mood === 'resting' ? 3 : 13)
        .borderRadius(7)
        .backgroundColor('#FFFFFF')
        .position({ x: 24, y: this.mood === 'resting' ? 40 : 33 })
      Column()
        .width(11)
        .height(this.mood === 'resting' ? 3 : 13)
        .borderRadius(7)
        .backgroundColor('#FFFFFF')
        .position({ x: 45, y: this.mood === 'resting' ? 40 : 33 })
      if (this.mood !== 'resting') {
        Column().width(6).height(8).borderRadius(4).backgroundColor('#1D1A3A').position({ x: 27, y: 38 })
        Column().width(6).height(8).borderRadius(4).backgroundColor('#1D1A3A').position({ x: 48, y: 38 })
      }
      // smile
      Column()
        .width(14)
        .height(7)
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 8, bottomRight: 8 })
        .backgroundColor('#1D1A3A')
        .position({ x: 33, y: 50 })
    }
    .width(80)
    .height(98)
    .scale({ x: 0.82, y: 0.82 })
    .margin({ top: -8, bottom: -8 })
  }

  build() {
    Column() {
      this.MiniWisp()
      Text(this.moodLabel)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F4F5FF')
        .margin({ top: 4 })
      Row({ space: 6 }) {
        Text('Train ' + this.train + '%')
          .fontSize(10)
          .fontColor('#B4B8E0')
        Text('Rec ' + this.recover + '%')
          .fontSize(10)
          .fontColor('#A0A3AE')
      }
      .margin({ top: 1 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8, bottom: 6, left: 6, right: 6 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#17181E')
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
