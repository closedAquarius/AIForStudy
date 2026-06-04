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

        Text('返回')
          .fontSize(16)
          .fontColor(this.themeColor)
      }
      .width(78)
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
        .textAlign(TextAlign.Center)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')
        .maxLines(1)

      Blank()
        .width(78)
    }
    .width('100%')
    .height(86)
    .padding({ left: 18, right: 18, top: 32 })
    .backgroundColor('#FFFFFF')
    .border({
      width: { bottom: 1 },
      color: '#EEF2F7'
    })
  }
}