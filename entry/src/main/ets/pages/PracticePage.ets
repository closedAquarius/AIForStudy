import { router } from '@kit.ArkUI';

@Entry
@Component
struct PracticePage {
  build() {
    Stack() {
      Image($r('app.media.main_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column({ space: 24 }) {
        Row() {
          Text('‹ 返回')
            .fontSize(18)
            .fontColor('#2D75FF')
            .onClick(() => {
              router.back();
            })

          Blank()
        }
        .width('100%')

        Image($r('app.media.big_icon1'))
          .width(150)
          .height(150)
          .objectFit(ImageFit.Contain)

        Text('题库刷题')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('Excel 导入题库，按标签、错题、已刷状态筛选。')
          .fontSize(16)
          .fontColor('#65718E')
          .lineHeight(24)
          .textAlign(TextAlign.Center)

        Text('功能开发中')
          .fontSize(15)
          .fontColor('#2D75FF')
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor('#EAF3FF')
      }
      .width('86%')
      .padding({ top: 56 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}