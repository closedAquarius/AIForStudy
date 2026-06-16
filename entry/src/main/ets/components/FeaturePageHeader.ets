import { router } from '@kit.ArkUI';
import { getAppTheme } from '../common/Theme';

@Component
export struct FeaturePageHeader {
  @Prop title: string = '';
  @Prop themeColor: string = '#2D75FF';

  private theme() {
    return getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined);
  }

  build() {
    Row() {
      Row({ space: 3 }) {
        Text('‹')
          .fontSize(30)
          .fontColor(this.themeColor.length > 0 ? this.themeColor : this.theme().accent)
          .margin({ bottom: 3 })
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(19)
      .backgroundColor(this.theme().accentSoft)
      .onClick(() => {
        router.back();
      })

      Text(this.title)
        .layoutWeight(1)
        .textAlign(TextAlign.LEFT)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .maxLines(1)
        .margin({left: 20})

      Blank()
        .width(78)
    }
    .width('100%')
    .height(58)
    .padding({ left: 18, right: 18, top: 10 })
    .backgroundColor(this.theme().surfaceBackground)
  }
}
