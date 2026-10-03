@Component
export struct StatBar {
  @Prop title: string = '';
  @Prop value: number = 0;
  @Prop color: string = '#7C9CFF';

  build() {
    Column() {
      Text(this.title)
        .fontSize(12)
        .fontColor('#9FA8DA')
      Text(Math.round(this.value * 100) + '%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#E8EAF6')
        .margin({ top: 2, bottom: 6 })
      Progress({ value: Math.round(this.value * 100), total: 100, type: ProgressType.Linear })
        .color(this.color)
        .backgroundColor('#34376B')
        .width('100%')
        .height(6)
    }
    .layoutWeight(1)
    .padding(10)
    .borderRadius(12)
    .backgroundColor('#1F2147')
    .alignItems(HorizontalAlign.Start)
  }
}
