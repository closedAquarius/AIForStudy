import { router } from '@kit.ArkUI';
import { login, LoginUser } from '../common/ApiClient';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
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

  private async doLogin(): Promise<void> {
    if (this.loading || !this.checkInput()) {
      return;
    }

    this.loading = true;
    this.message = '正在登录...';

    try {
      const result = await login(this.username.trim(), this.password);

      if (result.success && result.data?.user) {
        this.message = '登录成功';
        await this.goMain(result.data.user, result.data.token ?? '');
        return;
      }

      this.message = result.message || '登录失败，请检查用户名或密码';
    } catch (error) {
      this.message = `请求失败，请检查后端服务：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  LoginInput(placeholderText: string, isPassword: boolean) {
    if (isPassword) {
      TextInput({ placeholder: placeholderText, text: this.password })
        .width('84%')
        .height(62)
        .type(InputType.Password)
        .fontSize(20)
        .fontColor('#333333')
        .placeholderColor('#9E9E9E')
        .caretColor('#4D8FF7')
        .backgroundColor('#E2E2E2')
        .borderRadius(31)
        .padding({ left: 24, right: 24 })
        .onChange((value: string) => {
          this.password = value;
        })
    } else {
      TextInput({ placeholder: placeholderText, text: this.username })
        .width('84%')
        .height(62)
        .fontSize(20)
        .fontColor('#333333')
        .placeholderColor('#9E9E9E')
        .caretColor('#4D8FF7')
        .backgroundColor('#E2E2E2')
        .borderRadius(31)
        .padding({ left: 24, right: 24 })
        .onChange((value: string) => {
          this.username = value;
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
        Column({ space: 18 }) {
          Text('AI辅学')
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor('#5A96D8')
            .textAlign(TextAlign.Center)

          Text('AI赋能学习 · 智慧成就未来')
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7A7A7A')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .margin({ top: 152 })

        Column() {
          Column({ space: 32 }) {
            this.LoginInput('请输入用户名', false)

            this.LoginInput('请输入密码', true)

            Row() {
              Blank()

              Text('立即注册  >')
                .fontSize(18)
                .fontColor('#4D8FF7')
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/RegisterPage'
                  });
                })
            }
            .width('84%')
            .height(24)

            Button(this.loading ? '登录中...' : '立即登录')
              .width('84%')
              .height(62)
              .fontSize(26)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .borderRadius(31)
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
                this.doLogin();
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
          .margin({ top: 54 })
        }
        .width('86%')
        .height(386)
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