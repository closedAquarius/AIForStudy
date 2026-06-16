import { router } from '@kit.ArkUI';
import { getAppTheme } from '../common/Theme';

@Component
export struct FeatureBottomNav {
  @Prop selectedIndex: number = 0;

  private theme() {
    return getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined);
  }

  private goPage(index: number, url: string): void {
    if (this.selectedIndex === index) {
      return;
    }

    // 功能页点首页时回到原来的 MainPage，保留首页状态。
    if (index === 0) {
      router.back();
      return;
    }

    // 从首页进入功能页时压入页面栈，确保功能页顶部返回按钮可用。
    if (this.selectedIndex === 0) {
      router.pushUrl({
        url: url
      });
      return;
    }

    // 功能页之间切换时替换当前页面，避免页面栈过深。
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
            .backgroundColor(this.theme().accentSoft)
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
        .fontColor(this.selectedIndex === index ? this.theme().accent : this.theme().textMuted)
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
    .backgroundColor(this.theme().surfaceBackground)
    .border({ width: 1, color: this.theme().border })
  }
}
