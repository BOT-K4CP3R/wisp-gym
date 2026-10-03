// The creature for home-screen widgets, built from rounded boxes because widget cards
// cannot host a Canvas. Proportions, colour and expression mirror the in-app drawing.
// Authored in an 80 x 98 box; `scaleBy` scales it.
@Component
export struct MiniWisp {
  @Prop scaleBy: number = 1;
  @Prop eyes: string = 'open';        // open | half | closed | happy
  @Prop sparkle: boolean = false;
  @Prop hue: string = '#FF8A5B';
  @Prop hueLight: string = '#FFC2A3';
  @Prop hueDark: string = '#B4502C';
  @Prop legs: number = 1;
  @Prop push: number = 1;
  @Prop pull: number = 1;
  @Prop core: number = 1;

  @Builder
  Eye(x: number) {
    if (this.eyes === 'happy') {
      // "^" made of two short strokes
      Column().width(8).height(3).borderRadius(2).backgroundColor('#1D1A3A')
        .position({ x: x - 1, y: 38 }).rotate({ angle: -38 })
      Column().width(8).height(3).borderRadius(2).backgroundColor('#1D1A3A')
        .position({ x: x + 5, y: 38 }).rotate({ angle: 38 })
    } else if (this.eyes === 'closed') {
      Column().width(11).height(3).borderRadius(2).backgroundColor('#1D1A3A').position({ x: x, y: 40 })
    } else if (this.eyes === 'half') {
      Column().width(11).height(7).borderRadius({ topLeft: 2, topRight: 2, bottomLeft: 6, bottomRight: 6 })
        .backgroundColor('#FFFFFF').position({ x: x, y: 38 })
      Column().width(6).height(4).borderRadius(3).backgroundColor('#1D1A3A').position({ x: x + 3, y: 40 })
    } else {
      Column().width(11).height(13).borderRadius(7).backgroundColor('#FFFFFF').position({ x: x, y: 33 })
      Column().width(6).height(8).borderRadius(4).backgroundColor('#1D1A3A').position({ x: x + 3, y: 38 })
      Column().width(2).height(2).borderRadius(1).backgroundColor('#FFFFFF').position({ x: x + 4, y: 38 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // glowing tuft
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
        .position({ x: 30 - 20 * this.legs, y: 84 })
      Column()
        .width(20 * this.legs)
        .height(12 * this.legs)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 50, y: 84 })
      // arms: size follows "pull", spread follows "push"
      Column()
        .width(12 * this.pull)
        .height(32 * this.pull)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 12 - 10 * this.push, y: 48 })
        .rotate({ angle: 18 })
      Column()
        .width(12 * this.pull)
        .height(32 * this.pull)
        .borderRadius(10)
        .backgroundColor(this.hueDark)
        .position({ x: 68 + 10 * (this.push - 1) - 12 * (this.pull - 1), y: 48 })
        .rotate({ angle: -18 })
      // torso + belly
      Column()
        .width(56 * this.core)
        .height(52 * this.core)
        .borderRadius(28 * this.core)
        .linearGradient({ angle: 160, colors: [[this.hueLight, 0.0], [this.hue, 0.6], [this.hueDark, 1.0]] })
        .position({ x: 40 - 28 * this.core, y: 54 })
      Column()
        .width(30 * this.core)
        .height(28 * this.core)
        .borderRadius(16 * this.core)
        .backgroundColor('#66FFFFFF')
        .position({ x: 40 - 15 * this.core, y: 66 })
      // head
      Column()
        .width(56)
        .height(48)
        .borderRadius(26)
        .linearGradient({ angle: 160, colors: [[this.hueLight, 0.0], [this.hue, 1.0]] })
        .position({ x: 12, y: 16 })
      // cheeks
      Column().width(9).height(6).borderRadius(4).backgroundColor('#66FF6E96').position({ x: 17, y: 46 })
      Column().width(9).height(6).borderRadius(4).backgroundColor('#66FF6E96').position({ x: 54, y: 46 })
      this.Eye(23)
      this.Eye(46)
      // smile: wider and open when happy
      Column()
        .width(this.eyes === 'happy' || this.sparkle ? 16 : 12)
        .height(this.eyes === 'happy' || this.sparkle ? 8 : 5)
        .borderRadius({ topLeft: 1, topRight: 1, bottomLeft: 8, bottomRight: 8 })
        .backgroundColor(this.eyes === 'happy' || this.sparkle ? '#7A2342' : '#1D1A3A')
        .position({ x: this.eyes === 'happy' || this.sparkle ? 32 : 34, y: 50 })
      if (this.sparkle) {
        Column().width(7).height(7).backgroundColor('#FFF4BE').rotate({ angle: 45 }).position({ x: 2, y: 20 })
        Column().width(5).height(5).backgroundColor('#FFF4BE').rotate({ angle: 45 }).position({ x: 72, y: 8 })
        Column().width(5).height(5).backgroundColor('#CCFFF4BE').rotate({ angle: 45 }).position({ x: 74, y: 62 })
      }
      if (this.eyes === 'closed') {
        Text('z').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#E6F4F5FF').position({ x: 66, y: 6 })
        Text('z').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#99F4F5FF').position({ x: 74, y: -4 })
      }
    }
    .width(80)
    .height(98)
    .scale({ x: this.scaleBy, y: this.scaleBy })
  }
}
