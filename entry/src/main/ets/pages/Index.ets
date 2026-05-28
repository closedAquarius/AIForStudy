import { login, register, LoginUser } from '../common/ApiClient';

@Entry
@Component
struct Index {
  @State isLoginMode: boolean = true;
  @State username: string = 'student1';
  @State password: string = '123456';
  @State nickname: string = '';
  @State message: string = '';
  @State loading: boolean = false;
  @State currentUser: LoginUser | null = null;

  private async submit(): Promise<void> {
    if (this.loading) {
      return;
    }

    this.loading = true;
    this.message = this.isLoginMode ? '正在登录...' : '正在注册...';

    try {
      const result = this.isLoginMode
        ? await login(this.username, this.password)
        : await register(this.username, this.password, this.nickname);

      this.message = result.message;
      if (result.success && result.data?.user) {
        this.currentUser = result.data.user;
      }
    } catch (error) {
      this.message = `请求失败，请检查后端服务：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  FeatureItem(title: string, desc: string) {
    Row() {
      Column()
        .width(10)
        .height(44)
        .backgroundColor('#2563EB')
        .borderRadius(5)

      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
        Text(desc)
          .fontSize(12)
          .fontColor('#6B7280')
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#E5E7EB' })
  }

  @Builder
  AuthPanel() {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('AI 辅学')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text('题库、文档生成试卷、日记分析和 AI 问答的学习工作台')
          .fontSize(14)
          .fontColor('#4B5563')
          .textAlign(TextAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)

      Row() {
        Button('登录')
          .layoutWeight(1)
          .height(42)
          .backgroundColor(this.isLoginMode ? '#2563EB' : '#EEF2FF')
          .fontColor(this.isLoginMode ? '#FFFFFF' : '#1D4ED8')
          .onClick(() => {
            this.isLoginMode = true;
            this.message = '';
          })
        Button('注册')
          .layoutWeight(1)
          .height(42)
          .backgroundColor(!this.isLoginMode ? '#2563EB' : '#EEF2FF')
          .fontColor(!this.isLoginMode ? '#FFFFFF' : '#1D4ED8')
          .onClick(() => {
            this.isLoginMode = false;
            this.message = '';
          })
      }
      .width('100%')
      .height(48)
      .padding(3)
      .borderRadius(8)
      .backgroundColor('#EEF2FF')

      Column({ space: 12 }) {
        TextInput({ placeholder: '用户名', text: this.username })
          .height(48)
          .backgroundColor('#F9FAFB')
          .onChange((value: string) => {
            this.username = value;
          })

        if (!this.isLoginMode) {
          TextInput({ placeholder: '昵称', text: this.nickname })
            .height(48)
            .backgroundColor('#F9FAFB')
            .onChange((value: string) => {
              this.nickname = value;
            })
        }

        TextInput({ placeholder: '密码', text: this.password })
          .height(48)
          .type(InputType.Password)
          .backgroundColor('#F9FAFB')
          .onChange((value: string) => {
            this.password = value;
          })
      }
      .width('100%')

      Button(this.loading ? '处理中...' : (this.isLoginMode ? '登录' : '创建账号'))
        .width('100%')
        .height(48)
        .backgroundColor('#111827')
        .fontColor('#FFFFFF')
        .enabled(!this.loading)
        .onClick(() => {
          this.submit();
        })

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(13)
          .fontColor(this.message.includes('成功') ? '#047857' : '#B91C1C')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor('#FFFFFF')
    .border({ width: 1, color: '#E5E7EB' })
  }

  @Builder
  HomePanel() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text(`你好，${this.currentUser?.nickname ?? '同学'}`)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Text('今天从一个小目标开始。')
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('退出')
          .height(38)
          .backgroundColor('#F3F4F6')
          .fontColor('#374151')
          .onClick(() => {
            this.currentUser = null;
            this.message = '';
          })
      }
      .width('100%')

      Grid() {
        GridItem() {
          this.FeatureItem('题库刷题', 'Excel 导入题库，按标签、错题、已刷状态筛选')
        }
        GridItem() {
          this.FeatureItem('文档出题', '上传 PPT / Word 后调用 AI 生成题库或试卷')
        }
        GridItem() {
          this.FeatureItem('学习日记', '记录每日心得，后续接入 AI 状态分析')
        }
        GridItem() {
          this.FeatureItem('AI 辅学', '提问答疑、错题讲解、生成学习计划')
        }
      }
      .columnsTemplate('1fr')
      .rowsGap(12)
      .width('100%')

      Row({ space: 10 }) {
        Button('开始刷题')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#2563EB')
        Button('导入资料')
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#059669')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        if (this.currentUser) {
          this.HomePanel()
        } else {
          this.AuthPanel()
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20, top: 40, bottom: 40 })
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3F7FB')
  }
}
