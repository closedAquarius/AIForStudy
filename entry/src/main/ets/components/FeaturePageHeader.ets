import { router } from '@kit.ArkUI';

@Component
export struct FeaturePageHeader {
  @Prop title: string = '';
  @Prop themeColor: string = '#2D75FF';

  build() {
    Row() {
      Row({ space: 3 }) {
        Text('‹')
          .fontSize(30)
          .fontColor(this.themeColor)
          .margin({ bottom: 3 })
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(19)
      .backgroundColor('#EEF5FF')
      .onClick(() => {
        router.back();
      })

      Text(this.title)
        .layoutWeight(1)
        .textAlign(TextAlign.LEFT)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
        .maxLines(1)
        .margin({left: 20})

      Blank()
        .width(78)
    }
    .width('100%')
    .height(58)
    .padding({ left: 18, right: 18, top: 10 })
    .backgroundColor('#FFFFFF')
  }
}