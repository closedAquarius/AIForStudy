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
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(40)
          .height(40)
          .fill(this.theme().successSoft)

        Text(this.status === 'completed' ? '完' : '今')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().success)
      }

      Column({ space: 3 }) {
        Text('今日学习')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)

        Text(this.summaryText())
          .fontSize(11)
          .fontColor(this.theme().textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor(this.theme().success)
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.theme().cardBackground)
    .borderRadius(12)
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
  InfoBar(iconText: string, iconBg: string, iconColor: string, title: string, desc: string, pageUrl: string) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(36)
          .height(36)
          .fill(iconBg)

        Text(iconText)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(iconColor)
      }

      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)

        Text(desc)
          .fontSize(11)
          .fontColor(this.theme().textSecondary)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor(iconColor)
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.theme().surfaceBackground)
    .borderRadius(12)
    .border({ width: 1, color: this.theme().border })
    .onClick(() => {
      this.goPage(pageUrl);
    })
  }

  @Builder
  ModuleCard(icon: Resource, title: string, desc: string, bgColor: string, arrowColor: string, pageUrl: string) {
    Column() {
      Image(icon)
        .width('76%')
        .height(76)
        .objectFit(ImageFit.Contain)
        .margin({ top: 8 })

      Row() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .layoutWeight(1)
          .maxLines(1)

        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(30)
            .height(30)
            .fill(this.theme().surfaceBackground)

          Text('>')
            .fontSize(20)
            .fontColor(arrowColor)
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
        .margin({ top: 4 })
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
  SloganBar() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(38)
          .height(38)
          .fill(this.theme().accentSoft)

        Text('AI')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().accent)
      }
      .margin({ left: 14 })

      Text('AI For Study')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().accent)
        .layoutWeight(1)
        .margin({ left: 10 })

      Text('>')
        .fontSize(22)
        .fontColor(this.theme().textMuted)
        .margin({ right: 16 })
    }
    .width('100%')
    .height(50)
    .borderRadius(22)
    .backgroundColor(this.theme().surfaceBackground)
    .border({ width: 1, color: this.theme().border })
    .margin({ left: 22, right: 22, top: 12 })
  }

  build() {
    Column() {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme().pageBackground)

        Scroll() {
          Column() {
            this.TopBar()

            Column() {
              TodayStudySummary({
                completedCount: this.todayCompletedCount,
                totalCount: this.todayTotalCount,
                streakDays: this.todayStreakDays,
                status: this.todayStatus
              })
            }
            .margin({ left: 22, right: 22, top: 4 })
            .onClick(() => {
              this.goPage('pages/TodayStudyPage');
            })

            Column() {
              this.InfoBar('!', this.theme().dangerSoft, this.theme().danger, '我的错题本', '集中查看错题、解析和 AI 讲解', 'pages/WrongQuestionBookPage')
            }
            .margin({ left: 22, right: 22, top: 6 })

            Column() {
              this.InfoBar('*', this.theme().warningSoft, this.theme().warning, '我的收藏', '集中复习收藏题目和个人笔记', 'pages/FavoriteQuestionPage')
            }
            .margin({ left: 22, right: 22, top: 8 })

            Column() {
              this.InfoBar('K', this.theme().accentSoft, this.theme().accent, '文档知识库', '上传课程资料，提问并查看答案来源', 'pages/KnowledgeBasePage')
            }
            .margin({ left: 22, right: 22, top: 8 })

            Column() {
              this.InfoBar('G', this.theme().successSoft, this.theme().success, '知识图谱', '查看知识结构、掌握程度与薄弱知识点', 'pages/KnowledgeGraphPage')
            }
            .margin({ left: 22, right: 22, top: 8 })

            Grid() {
              GridItem() {
                this.ModuleCard(
                  $r('app.media.big_icon1'),
                  '题库刷题',
                  '按标签、错题和学习状态筛选练习',
                  this.theme().cardBackground,
                  this.theme().accent,
                  'pages/PracticePage'
                )
              }

              GridItem() {
                this.ModuleCard(
                  $r('app.media.big_icon2'),
                  '文档出题',
                  '上传 PPT 或 Word，交给 AI 生成题目',
                  this.theme().successSoft,
                  this.theme().success,
                  'pages/SetQuestionPage'
                )
              }

              GridItem() {
                this.ModuleCard(
                  $r('app.media.big_icon3'),
                  '学习日记',
                  '记录每日心得，结合 AI 做状态分析',
                  this.theme().secondarySurface,
                  this.theme().accent,
                  'pages/DiaryPage'
                )
              }

              GridItem() {
                this.ModuleCard(
                  $r('app.media.big_icon4'),
                  'AI辅学',
                  '提问答疑、错题讲解和学习规划',
                  this.theme().warningSoft,
                  this.theme().warning,
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
            .margin({ top: 12 })

            Column() {
              this.SloganBar()
            }
            .margin({ bottom: 18 })
          }
          .width('100%')
          .padding({ bottom: 16 })
        }
        .scrollBar(BarState.Off)
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
