import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  private goLogin(): void {
    router.pushUrl({
      url: 'pages/LoginPage'
    });
  }

  @Builder
  FeatureCard(icon: string, title: string, desc: string) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(24)
        .width(48)
        .height(48)
        .textAlign(TextAlign.Center)
        .borderRadius(16)
        .backgroundColor('#EEF2FF')

      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')

        Text(desc)
          .fontSize(12)
          .fontColor('#6B7280')
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#EEF2F7' })
  }

  build() {
    Scroll() {
      Column({ space: 26 }) {
        Column({ space: 10 }) {
          Text('AI 辅学')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')

          Text('让刷题、资料整理、学习日记和 AI 答疑变得更轻松')
            .fontSize(15)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)
            .lineHeight(23)
        }
        .width('100%')
        .margin({ top: 40 })

        Column({ space: 14 }) {
          this.FeatureCard('📚', '智能题库', '支持题目练习、错题整理、标签分类')
          this.FeatureCard('📝', '文档出题', '后续可接入 Word / PPT 文档生成试卷')
          this.FeatureCard('🤖', 'AI 答疑', '围绕知识点解释、错题讲解和学习规划')
          this.FeatureCard('🌙', '学习日记', '记录学习状态，为后续 AI 分析做准备')
        }
        .width('100%')

        Button('立即进入')
          .width('100%')
          .height(52)
          .borderRadius(18)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#2563EB')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.goLogin();
          })

        Text('课程项目 · HarmonyOS ArkTS')
          .fontSize(12)
          .fontColor('#9CA3AF')
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 24, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FC')
  }
}