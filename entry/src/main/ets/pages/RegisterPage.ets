import { router } from '@kit.ArkUI';
import { register, LoginUser } from '../common/ApiClient';

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State nickname: string = '';
  @State message: string = '';
  @State loading: boolean = false;

  private checkInput(): boolean {
    if (this.username.trim().length === 0) {
      this.message = '请输入用户名';
      return false;
    }

    if (this.password.trim().length === 0) {
      this.message = '请输入密码';
      return false;
    }

    if (this.nickname.trim().length === 0) {
      this.nickname = this.username.trim();
    }

    return true;
  }

  private async goMain(user: LoginUser, token: string = ''): Promise<void> {
    await router.replaceUrl({
      url: 'pages/MainPage',
      params: {
        user: JSON.stringify(user),
        token: token
      }
    });
  }

  private async doRegister(): Promise<void> {
    if (this.loading || !this.checkInput()) {
      return;
    }

    this.loading = true;
    this.message = '正在注册...';

    try {
      const result = await register(
        this.username.trim(),
        this.password,
        this.nickname.trim()
      );

      if (result.success && result.data?.user) {
        this.message = '注册成功';
        await this.goMain(result.data.user, result.data.token ?? '');
        return;
      }

      this.message = result.message || '注册失败，请稍后再试';
    } catch (error) {
      this.message = `请求失败，请检查后端服务：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  RegisterInput(placeholderText: string, valueType: string) {
    if (valueType === 'username') {
      TextInput({ placeholder: placeholderText, text: this.username })
        .width('84%')
        .height(56)
        .fontSize(18)
        .fontColor('#333333')
        .placeholderColor('#9E9E9E')
        .caretColor('#4D8FF7')
        .backgroundColor('#E2E2E2')
        .borderRadius(28)
        .padding({ left: 22, right: 22 })
        .onChange((value: string) => {
          this.username = value;
        })
    } else if (valueType === 'nickname') {
      TextInput({ placeholder: placeholderText, text: this.nickname })
        .width('84%')
        .height(56)
        .fontSize(18)
        .fontColor('#333333')
        .placeholderColor('#9E9E9E')
        .caretColor('#4D8FF7')
        .backgroundColor('#E2E2E2')
        .borderRadius(28)
        .padding({ left: 22, right: 22 })
        .onChange((value: string) => {
          this.nickname = value;
        })
    } else {
      TextInput({ placeholder: placeholderText, text: this.password })
        .width('84%')
        .height(56)
        .type(InputType.Password)
        .fontSize(18)
        .fontColor('#333333')
        .placeholderColor('#9E9E9E')
        .caretColor('#4D8FF7')
        .backgroundColor('#E2E2E2')
        .borderRadius(28)
        .padding({ left: 22, right: 22 })
        .onChange((value: string) => {
          this.password = value;
        })
    }
  }

  build() {
    Stack() {
      Image($r('app.media.login_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column() {
        Column({ space: 14 }) {
          Text('创建账号')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor('#5A96D8')
            .textAlign(TextAlign.Center)

          Text('加入 AI 辅学，开启智慧学习')
            .fontSize(20)
            .fontColor('#7A7A7A')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .margin({ top: 128 })

        Column() {
          Column({ space: 22 }) {
            this.RegisterInput('请输入用户名', 'username')

            this.RegisterInput('请输入昵称', 'nickname')

            this.RegisterInput('请输入密码', 'password')

            Button(this.loading ? '注册中...' : '立即注册')
              .width('84%')
              .height(58)
              .fontSize(24)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .borderRadius(29)
              .backgroundColor('#00000000')
              .linearGradient({
                direction: GradientDirection.Right,
                colors: [
                  ['#4387F5', 0.0],
                  ['#68A7FF', 1.0]
                ]
              })
              .enabled(!this.loading)
              .onClick(() => {
                this.doRegister();
              })

            Text('已有账号？返回登录')
              .fontSize(16)
              .fontColor('#4D8FF7')
              .onClick(() => {
                router.back();
              })

            if (this.message.length > 0) {
              Text(this.message)
                .width('84%')
                .fontSize(13)
                .fontColor(this.message.includes('成功') || this.message.includes('正在') ? '#2563EB' : '#DC2626')
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 36 })
        }
        .width('86%')
        .height(430)
        .borderRadius(22)
        .backgroundColor('#EFFFFFFF')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 28 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}