import { router } from '@kit.ArkUI';
import { LoginUser, TodayReviewPlanData, getTodayReviewPlan } from '../common/ApiClient';
import { FeatureBottomNav } from '../components/FeatureBottomNav';

@Component
struct TodayStudySummary {
  @Prop completedCount: number = 0;
  @Prop totalCount: number = 0;
  @Prop streakDays: number = 0;
  @Prop status: string = 'pending';

  build() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(40)
          .height(40)
          .fill('#E9FBF2')

        Text(this.status === 'completed' ? '✓' : '今')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#16A66A')
      }

      Column({ space: 3 }) {
        Text('今日学习')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text(this.totalCount > 0
          ? `${this.completedCount}/${this.totalCount} 题 · 连续 ${this.streakDays} 天`
          : '今天暂无到期任务')
          .fontSize(11)
          .fontColor('#64748B')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor('#16A66A')
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#F5FFFA')
    .borderRadius(12)
    .border({ width: 1, color: '#C8EEDB' })
  }
}

@Entry
@Component
struct MainPage {
  @State nickname: string = '用户名';
  @State todayCompletedCount: number = 0;
  @State todayTotalCount: number = 0;
  @State todayStreakDays: number = 0;
  @State todayStatus: string = 'pending';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;

    if (params) {
      const userText = params['user'] ?? '';
      if (userText.length > 0) {
        try {
          const user = JSON.parse(userText) as LoginUser;
          this.nickname = user.nickname || user.username || '用户名';
        } catch (error) {
          this.nickname = '用户名';
        }
      }
    }
    const currentUser = this.getCurrentUser();
    if (currentUser) {
      this.nickname = currentUser.nickname || currentUser.username;
    }
    this.loadTodaySummary();
  }

  onPageShow(): void {
    this.loadTodaySummary();
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
    } catch (error) {
      this.todayCompletedCount = 0;
      this.todayTotalCount = 0;
    }
  }

  private getCurrentUser(): LoginUser | undefined {
    const userText = AppStorage.Get<string>('currentUser') ?? '';
    if (userText.length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(userText) as LoginUser;
    } catch (error) {
      return undefined;
    }
  }

  private getAvatarUrl(): string {
    const user = this.getCurrentUser();
    return user?.avatarUrl || 'ailearning_icon.png';
  }

  private goProfile(): void {
    router.pushUrl({
      url: 'pages/ProfilePage'
    });
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

  private logout(): void {
    AppStorage.SetOrCreate<string>('token', '');
    AppStorage.SetOrCreate<string>('currentUser', '');
    router.replaceUrl({
      url: 'pages/LoginPage'
    });
  }

  private goPage(url: string): void {
    router.pushUrl({
      url: url
    });
  }

  @Builder
  TopBar() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(30)
            .height(30)
            .fill('#EFFFFFFF')

          this.UserAvatar()
        }
        .onClick(() => {
          this.goProfile();
        })

        Text(`您好，${this.nickname}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')
          .maxLines(1)
      }
      .layoutWeight(1)

      Button() {
        Row({ space: 5 }) {
          Text('退出')
            .fontSize(16)
            .fontColor('#2F76FF')
        }
        .padding({ left: 14, right: 16 })
      }
      .height(35)
      .borderRadius(22)
      .backgroundColor('#E6FFFFFF')
      .border({ width: 1, color: '#FFFFFFFF' })
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
          .fontColor('#0B1B44')
          .layoutWeight(1)
          .maxLines(1)

        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(30)
            .height(30)
            .fill('#F4F7FF')

          Text('›')
            .fontSize(25)
            .fontColor(arrowColor)
            .margin({ bottom: 3 })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 12 })
      .margin({ top: 2 })

      Text(desc)
        .width('100%')
        .fontSize(12)
        .fontColor('#65718E')
        .lineHeight(17)
        .padding({ left: 14, right: 10 })
        .margin({ top: 4 })
        .maxLines(2)
    }
    .width('100%')
    .height(154)
    .borderRadius(22)
    .backgroundColor(bgColor)
    .border({ width: 1, color: '#FFFFFFFF' })
    .shadow({
      radius: 10,
      color: '#146EA8FF',
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
          .fill('#EAF3FF')

        Text('♛')
          .fontSize(18)
          .fontColor('#347DFF')
      }
      .margin({ left: 14 })

      Text('AI 赋能学习 · 智慧成就未来')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2D75FF')
        .layoutWeight(1)
        .margin({ left: 10 })

      Text('›')
        .fontSize(27)
        .fontColor('#6A9BFF')
        .margin({ right: 16, bottom: 3 })
    }
    .width('100%')
    .height(50)
    .borderRadius(22)
    .backgroundColor('#DFFFFFFF')
    .border({ width: 1, color: '#FFFFFFFF' })
    .margin({ left: 22, right: 22, top: 12 })
  }

  @Builder
  WrongQuestionBookBar() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(36)
          .height(36)
          .fill('#FFF1F2')

        Text('!')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#EF4444')
      }

      Column({ space: 2 }) {
        Text('我的错题本')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('集中查看错题、解析和 AI 讲解')
          .fontSize(11)
          .fontColor('#64748B')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor('#EF4444')
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .margin({ left: 22, right: 22, top: 6 })
    .backgroundColor('#F9FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#FFE0E3' })
    .onClick(() => {
      this.goPage('pages/WrongQuestionBookPage');
    })
  }

  @Builder
  FavoriteQuestionBar() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(36)
          .height(36)
          .fill('#FFF7E6')

        Text('★')
          .fontSize(18)
          .fontColor('#D97706')
      }

      Column({ space: 2 }) {
        Text('我的收藏')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('集中复习收藏题目和个人笔记')
          .fontSize(11)
          .fontColor('#64748B')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor('#D97706')
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .margin({ left: 22, right: 22, top: 8 })
    .backgroundColor('#F9FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#FDE7B2' })
    .onClick(() => {
      this.goPage('pages/FavoriteQuestionPage');
    })
  }

  @Builder
  KnowledgeBaseBar() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(36)
          .height(36)
          .fill('#EEF5FF')

        Text('K')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2563EB')
      }

      Column({ space: 2 }) {
        Text('文档知识库')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('上传课程资料，提问并查看答案来源')
          .fontSize(11)
          .fontColor('#64748B')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(20)
        .fontColor('#2563EB')
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .margin({ left: 22, right: 22, top: 8 })
    .backgroundColor('#F9FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#DCEAFF' })
    .onClick(() => {
      this.goPage('pages/KnowledgeBasePage');
    })
  }

  @Builder
  KnowledgeGraphBar() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(36).height(36).fill('#ECFDF5')
        Text('G').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#16805A')
      }
      Column({ space: 2 }) {
        Text('知识图谱').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#0B1B44')
        Text('查看知识结构、掌握程度与薄弱知识点').fontSize(11).fontColor('#64748B')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('>').fontSize(20).fontColor('#16805A')
    }
    .width('100%').height(56).padding({ left: 14, right: 14 })
    .margin({ left: 22, right: 22, top: 8 })
    .backgroundColor('#F9FFFFFF').borderRadius(12)
    .border({ width: 1, color: '#C8EEDB' })
    .onClick(() => this.goPage('pages/KnowledgeGraphPage'))
  }

  build() {
    Stack() {
      Image($r('app.media.main_background2'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column() {
        this.TopBar()

        TodayStudySummary({
          completedCount: this.todayCompletedCount,
          totalCount: this.todayTotalCount,
          streakDays: this.todayStreakDays,
          status: this.todayStatus
        })
          .margin({ left: 22, right: 22, top: 4 })
          .onClick(() => {
            this.goPage('pages/TodayStudyPage');
          })

        this.WrongQuestionBookBar()
        this.FavoriteQuestionBar()
        this.KnowledgeBaseBar()
        this.KnowledgeGraphBar()

        Blank()
          .layoutWeight(1)

        Grid() {
          GridItem() {
            this.ModuleCard(
              $r('app.media.big_icon1'),
              '题库刷题',
              'Excel 导入题库，按标签、错题、已刷状态筛选',
              '#F8FBFF',
              '#4B8EFF',
              'pages/PracticePage'
            )
          }

          GridItem() {
            this.ModuleCard(
              $r('app.media.big_icon2'),
              '文档出题',
              '上传 PPT / Word 后 AI 生成题库或试卷',
              '#F1FFF9',
              '#38C98A',
              'pages/SetQuestionPage'
            )
          }

          GridItem() {
            this.ModuleCard(
              $r('app.media.big_icon3'),
              '学习日记',
              '记录每日学习心得，AI 学习状态分析',
              '#FAF6FF',
              '#8B67FF',
              'pages/DiaryPage'
            )
          }

          GridItem() {
            this.ModuleCard(
              $r('app.media.big_icon4'),
              'AI辅学',
              '提问答疑、错题讲解、生成学习计划',
              '#FFF8EE',
              '#FFAA45',
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

        this.SloganBar()

        FeatureBottomNav({
          selectedIndex: 0
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
