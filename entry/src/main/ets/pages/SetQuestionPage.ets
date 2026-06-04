import { router } from '@kit.ArkUI';

@Entry
@Component
struct SetQuestionPage {
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

        Image($r('app.media.big_icon2'))
          .width(150)
          .height(150)
          .objectFit(ImageFit.Contain)

        Text('文档出题')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('上传 PPT / Word 后 AI 生成题库或试卷。')
          .fontSize(16)
          .fontColor('#65718E')
          .lineHeight(24)
          .textAlign(TextAlign.Center)

        Text('功能开发中')
          .fontSize(15)
          .fontColor('#38C98A')
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor('#E8FFF5')
      }
      .width('86%')
      .padding({ top: 56 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}