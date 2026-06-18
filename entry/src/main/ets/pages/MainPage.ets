import { router } from '@kit.ArkUI';
import { LoginUser, TodayReviewPlanData, getTodayReviewPlan } from '../common/ApiClient';
import { AppTheme, DEFAULT_THEME_ID, getAppTheme } from '../common/Theme';
import { FeatureBottomNav } from '../components/FeatureBottomNav';

@Component
struct TodayStudySummary {
  @Prop completedCount: number = 0;
  @Prop totalCount: number = 0;
  @Prop streakDays: number = 0;
  @Prop status: string = 'pending';

  private theme(): AppTheme {
    return getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined);
  }

  private summaryText(): string {
    if (this.totalCount > 0) {
      return `${this.completedCount}/${this.totalCount} 题，连续 ${this.streakDays} 天`;
    }
    return '今天暂时没有学习任务';
  }

  build() {
    Row() {
      Text(`今日学习：${this.summaryText()}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().textPrimary)
        .maxLines(1)
        .layoutWeight(1)

      Image($r('app.media.next_blue'))
        .height(20)
        .width(20)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height(44)
    .padding({ left: 22, right: 22 })
    .backgroundColor(this.theme().surfaceBackground)
    .borderRadius(14)
    .border({ width: 1, color: this.theme().border })
  }
}

@Entry
@Component
struct MainPage {
  @StorageLink('appThemeId') themeId: string = DEFAULT_THEME_ID;
  @State nickname: string = '用户';
  @State todayCompletedCount: number = 0;
  @State todayTotalCount: number = 0;
  @State todayStreakDays: number = 0;
  @State todayStatus: string = 'pending';

  aboutToAppear(): void {
    const currentUser = this.getCurrentUser();
    if (currentUser) {
      this.nickname = currentUser.nickname || currentUser.username || '用户';
    }
    this.loadTodaySummary();
  }

  onPageShow(): void {
    const currentUser = this.getCurrentUser();
    if (currentUser) {
      this.nickname = currentUser.nickname || currentUser.username || '用户';
    }
    this.loadTodaySummary();
  }

  private theme(): AppTheme {
    return getAppTheme(this.themeId);
  }

  private async loadTodaySummary(): Promise<void> {
    const token = AppStorage.Get<string>('token') ?? '';
    if (token.length === 0) {
      return;
    }

    try {
      const result = await getTodayReviewPlan(token);
      if (result.success && result.data) {
        const plan: TodayReviewPlanData = result.data;
        this.todayCompletedCount = plan.completedCount;
        this.todayTotalCount = plan.totalCount;
        this.todayStreakDays = plan.streakDays;
        this.todayStatus = plan.status;
      }
    } catch (_) {
      this.todayCompletedCount = 0;
      this.todayTotalCount = 0;
      this.todayStreakDays = 0;
      this.todayStatus = 'pending';
    }
  }

  private getCurrentUser(): LoginUser | undefined {
    const userText = AppStorage.Get<string>('currentUser') ?? '';
    if (userText.length === 0) {
      return undefined;
    }

    try {
      return JSON.parse(userText) as LoginUser;
    } catch (_) {
      return undefined;
    }
  }

  private getAvatarUrl(): string {
    const user = this.getCurrentUser();
    return user?.avatarUrl || 'ailearning_icon.png';
  }

  private goProfile(): void {
    router.pushUrl({ url: 'pages/ProfilePage' });
  }

  private logout(): void {
    AppStorage.SetOrCreate<string>('token', '');
    AppStorage.SetOrCreate<string>('currentUser', '');
    router.replaceUrl({ url: 'pages/LoginPage' });
  }

  private goPage(url: string): void {
    router.pushUrl({ url: url });
  }

  @Builder
  UserAvatar() {
    if (this.getAvatarUrl() === 'ailearning_icon.png') {
      Image($r('app.media.ailearning_icon'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Cover)
        .borderRadius(12)
    } else {
      Image(this.getAvatarUrl())
        .width(24)
        .height(24)
        .objectFit(ImageFit.Cover)
        .borderRadius(12)
    }
  }

  @Builder
  TopBar() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(30)
            .height(30)
            .fill(this.theme().accentSoft)

          this.UserAvatar()
        }
        .onClick(() => {
          this.goProfile();
        })

        Text(`你好，${this.nickname}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .maxLines(1)
      }
      .layoutWeight(1)

      Button('退出')
        .height(35)
        .fontSize(14)
        .fontColor(this.theme().accent)
        .backgroundColor(this.theme().surfaceBackground)
        .borderRadius(22)
        .border({ width: 1, color: this.theme().border })
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
    .height(58)
    .padding({ left: 22, right: 22 })
    .margin({ top: 10 })
  }

  @Builder
  QuickNavItem(icon: Resource, title: string, pageUrl: string) {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Contain)
      }

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)
        .maxLines(1)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(76)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.goPage(pageUrl);
    })
  }

  @Builder
  QuickNavBar() {
    Grid() {
      GridItem() {
        this.QuickNavItem(
          $r('app.media.mistakeBook'),
          '错题本',
          'pages/WrongQuestionBookPage'
        )
      }

      GridItem() {
        this.QuickNavItem(
          $r('app.media.myStar'),
          '收藏',
          'pages/FavoriteQuestionPage'
        )
      }

      GridItem() {
        this.QuickNavItem(
          $r('app.media.knowledgeBase'),
          '文档知识库',
          'pages/KnowledgeBasePage'
        )
      }

      GridItem() {
        this.QuickNavItem(
          $r('app.media.knowledgeGraph'),
          '知识图谱',
          'pages/KnowledgeGraphPage'
        )
      }
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .rowsTemplate('1fr')
    .columnsGap(4)
    .width('100%')
    .height(92)
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .backgroundColor('#F8FFFFFF')
    .borderRadius(22)
    .border({ width: 1, color: this.theme().border })
  }

  @Builder
  ModuleCard(icon: Resource, title: string, desc: string, bgColor: string, next: Resource, pageUrl: string) {
    Column() {
      Image(icon)
        .width('76%')
        .height(76)
        .objectFit(ImageFit.Contain)
        .margin({ top: 5 })

      Row() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(26)
            .height(26)
            .fill(this.theme().surfaceBackground)

          Image(next)
            .height(22)
            .width(22)
            .objectFit(ImageFit.Contain)
        }
      }
      .width('100%')
      .padding({ left: 14, right: 12 })
      .margin({ top: 2 })

      Text(desc)
        .width('100%')
        .fontSize(12)
        .fontColor(this.theme().textSecondary)
        .lineHeight(17)
        .padding({ left: 14, right: 10 })
        .margin({ top: 2 })
        .maxLines(2)
    }
    .width('100%')
    .height(154)
    .borderRadius(22)
    .backgroundColor(bgColor)
    .border({ width: 1, color: this.theme().border })
    .shadow({
      radius: 10,
      color: this.theme().shadow,
      offsetX: 0,
      offsetY: 5
    })
    .onClick(() => {
      this.goPage(pageUrl);
    })
  }

  @Builder
  MainModuleGrid() {
    Grid() {
      GridItem() {
        this.ModuleCard(
          $r('app.media.big_icon1'),
          '题库刷题',
          '按标签、错题和学习状态筛选练习',
          '#EDF7FF',
          $r('app.media.next_blue'),
          'pages/PracticePage'
        )
      }

      GridItem() {
        this.ModuleCard(
          $r('app.media.big_icon2'),
          '文档出题',
          '上传 PPT 或 Word，交给 AI 生成题目',
          this.theme().successSoft,
          $r('app.media.next_green'),
          'pages/SetQuestionPage'
        )
      }

      GridItem() {
        this.ModuleCard(
          $r('app.media.big_icon3'),
          '学习日记',
          '记录每日心得，结合 AI 做状态分析',
          '#FCF6FF',
          $r('app.media.next_purple'),
          'pages/DiaryPage'
        )
      }

      GridItem() {
        this.ModuleCard(
          $r('app.media.big_icon4'),
          'AI辅学',
          '提问答疑、错题讲解和学习规划',
          this.theme().warningSoft,
          $r('app.media.next_yellow'),
          'pages/AiLearningPage'
        )
      }
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(14)
    .rowsGap(14)
    .width('100%')
    .height(322)
    .padding({ left: 22, right: 22 })
  }

  build() {
    Column() {
      Stack() {
        Image($r('app.media.main_background2'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)

        Column() {
          this.TopBar()

          Column() {
            this.QuickNavBar()
          }
          .width('100%')
          .padding({ left: 22, right: 22 })
          .margin({ top: 160 })

          Scroll() {
            Column() {
              this.MainModuleGrid()
            }
            .width('100%')
            .padding({ top: 14, bottom: 14 })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)

          Column() {
            TodayStudySummary({
              completedCount: this.todayCompletedCount,
              totalCount: this.todayTotalCount,
              streakDays: this.todayStreakDays,
              status: this.todayStatus
            })
          }
          .width('100%')
          .padding({ left: 22, right: 22 })
          .margin({ bottom: 10 })
          .onClick(() => {
            this.goPage('pages/TodayStudyPage');
          })
        }
        .width('100%')
        .height('100%')
      }
      .layoutWeight(1)
      .width('100%')

      FeatureBottomNav({
        selectedIndex: 0
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().pageBackground)
  }
}