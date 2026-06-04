import { router } from '@kit.ArkUI';

@Component
export struct FeatureBottomNav {
  @Prop selectedIndex: number = 0;

  private goPage(index: number, url: string): void {
    if (this.selectedIndex === index) {
      return;
    }

    // 功能页点击首页：回到原来的 MainPage，保留 MainPage 的用户名等状态
    if (index === 0) {
      router.back();
      return;
    }

    // 从首页进入功能页：压入页面栈，保证功能页顶部返回按钮可以回首页
    if (this.selectedIndex === 0) {
      router.pushUrl({
        url: url
      });
      return;
    }

    // 功能页之间切换：替换当前功能页，避免页面栈过深
    router.replaceUrl({
      url: url
    });
  }

  @Builder
  NavItem(icon: Resource, title: string, index: number, url: string) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.selectedIndex === index) {
          Column()
            .width(50)
            .height(38)
            .borderRadius(15)
            .backgroundColor('#EAF3FF')
        }

        Image(icon)
          .width(25)
          .height(25)
          .objectFit(ImageFit.Contain)
      }
      .width(54)
      .height(38)

      Text(title)
        .fontSize(12)
        .fontWeight(this.selectedIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedIndex === index ? '#2D75FF' : '#8A96AD')
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.goPage(index, url);
    })
  }

  build() {
    Row() {
      this.NavItem($r('app.media.main_icon'), '首页', 0, 'pages/MainPage')
      this.NavItem($r('app.media.practice_icon'), '题库刷题', 1, 'pages/PracticePage')
      this.NavItem($r('app.media.setquestion_icon'), '文档出题', 2, 'pages/SetQuestionPage')
      this.NavItem($r('app.media.diary_icon'), '学习日记', 3, 'pages/DiaryPage')
      this.NavItem($r('app.media.ailearning_icon'), 'AI辅学', 4, 'pages/AiLearningPage')
    }
    .width('100%')
    .height(78)
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .backgroundColor('#F4FFFFFF')
    .border({ width: 1, color: '#FFFFFFFF' })
  }
}