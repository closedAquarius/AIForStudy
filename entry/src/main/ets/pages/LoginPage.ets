import { router } from '@kit.ArkUI';
import {
  LoginUser,
  login,
  resetPasswordByEmail,
  sendPasswordResetCode
} from '../common/ApiClient';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State message: string = '';
  @State loading: boolean = false;

  @State showResetDialog: boolean = false;
  @State resetEmail: string = '';
  @State resetCode: string = '';
  @State resetPassword: string = '';
  @State resetPasswordConfirm: string = '';
  @State resetMessage: string = '';
  @State sendingCode: boolean = false;
  @State resettingPassword: boolean = false;
  @State countdown: number = 0;
  private countdownTimer: number = -1;

  aboutToDisappear(): void {
    this.stopCountdown();
  }

  onBackPress(): boolean {
    if (this.showResetDialog) {
      this.closeResetDialog();
      return true;
    }
    return false;
  }

  private checkInput(): boolean {
    if (this.username.trim().length === 0) {
      this.message = '请输入用户名';
      return false;
    }
    if (this.password.length === 0) {
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
        AppStorage.SetOrCreate<string>('token', result.data.token ?? '');
        AppStorage.SetOrCreate<string>('currentUser', JSON.stringify(result.data.user));
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

  private openResetDialog(): void {
    this.resetEmail = '';
    this.resetCode = '';
    this.resetPassword = '';
    this.resetPasswordConfirm = '';
    this.resetMessage = '';
    this.showResetDialog = true;
  }

  private closeResetDialog(): void {
    if (!this.sendingCode && !this.resettingPassword) {
      this.showResetDialog = false;
      this.stopCountdown();
    }
  }

  private startCountdown(): void {
    this.stopCountdown();
    this.countdown = 60;
    this.countdownTimer = setInterval(() => {
      if (this.countdown <= 1) {
        this.stopCountdown();
        this.countdown = 0;
      } else {
        this.countdown -= 1;
      }
    }, 1000);
  }

  private stopCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private async sendResetCode(): Promise<void> {
    const email = this.resetEmail.trim();
    if (this.sendingCode || this.countdown > 0) {
      return;
    }
    if (email.length === 0 || email.indexOf('@') < 1) {
      this.resetMessage = '请输入正确的邮箱地址';
      return;
    }

    this.sendingCode = true;
    this.resetMessage = '正在发送验证码...';
    try {
      const result = await sendPasswordResetCode(email);
      if (result.success) {
        this.resetMessage = '验证码已发送，请检查邮箱';
        this.startCountdown();
      } else {
        this.resetMessage = result.message || '验证码发送失败';
      }
    } catch (error) {
      this.resetMessage = `验证码发送失败：${(error as Error).message}`;
    } finally {
      this.sendingCode = false;
    }
  }

  private async confirmResetPassword(): Promise<void> {
    if (this.resettingPassword) {
      return;
    }
    if (this.resetEmail.trim().length === 0) {
      this.resetMessage = '请输入邮箱';
      return;
    }
    if (this.resetCode.trim().length !== 6) {
      this.resetMessage = '请输入 6 位验证码';
      return;
    }
    if (this.resetPassword.length < 6) {
      this.resetMessage = '新密码至少需要 6 个字符';
      return;
    }
    if (this.resetPassword !== this.resetPasswordConfirm) {
      this.resetMessage = '两次输入的新密码不一致';
      return;
    }

    this.resettingPassword = true;
    this.resetMessage = '正在重置密码...';
    try {
      const result = await resetPasswordByEmail(
        this.resetEmail.trim(),
        this.resetCode.trim(),
        this.resetPassword
      );
      if (result.success) {
        this.message = '密码重置成功，请使用新密码登录';
        this.showResetDialog = false;
        this.stopCountdown();
      } else {
        this.resetMessage = result.message || '密码重置失败';
      }
    } catch (error) {
      this.resetMessage = `密码重置失败：${(error as Error).message}`;
    } finally {
      this.resettingPassword = false;
    }
  }

  @Builder
  LoginInput(placeholderText: string, isPassword: boolean) {
    TextInput({
      placeholder: placeholderText,
      text: isPassword ? this.password : this.username
    })
      .width('84%')
      .height(62)
      .type(isPassword ? InputType.Password : InputType.Normal)
      .fontSize(20)
      .fontColor('#333333')
      .placeholderColor('#9E9E9E')
      .caretColor('#4D8FF7')
      .backgroundColor('#E2E2E2')
      .borderRadius(31)
      .padding({ left: 24, right: 24 })
      .onChange((value: string) => {
        if (isPassword) {
          this.password = value;
        } else {
          this.username = value;
        }
      })
  }

  @Builder
  ResetInput(placeholderText: string, inputType: InputType, value: string, action: (value: string) => void) {
    TextInput({ placeholder: placeholderText, text: value })
      .width('100%')
      .height(44)
      .type(inputType)
      .fontSize(14)
      .fontColor('#1F2937')
      .backgroundColor('#F3F5F8')
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .onChange(action)
  }

  @Builder
  ResetPasswordDialog() {
    Column({ space: 14 }) {
      Row() {
        Text('找回密码')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')
          .layoutWeight(1)

        Button('x')
          .width(32)
          .height(32)
          .fontSize(14)
          .fontColor('#64748B')
          .backgroundColor('#EEF2F7')
          .borderRadius(8)
          .onClick(() => {
            this.closeResetDialog();
          })
      }
      .width('100%')

      Text('验证码将发送到账号绑定的邮箱，有效期 10 分钟。')
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor('#64748B')

      this.ResetInput('请输入绑定邮箱', InputType.Email, this.resetEmail, (value: string) => {
        this.resetEmail = value;
      })

      Row({ space: 8 }) {
        TextInput({ placeholder: '6 位验证码', text: this.resetCode })
          .layoutWeight(1)
          .height(44)
          .type(InputType.Number)
          .maxLength(6)
          .fontSize(14)
          .backgroundColor('#F3F5F8')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.resetCode = value;
          })

        Button(
          this.sendingCode
            ? '发送中'
            : (this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
        )
          .width(104)
          .height(44)
          .fontSize(12)
          .fontColor(this.countdown > 0 ? '#94A3B8' : '#2563EB')
          .backgroundColor('#EEF5FF')
          .borderRadius(8)
          .enabled(!this.sendingCode && this.countdown === 0)
          .onClick(() => {
            this.sendResetCode();
          })
      }
      .width('100%')

      this.ResetInput('请输入新密码', InputType.Password, this.resetPassword, (value: string) => {
        this.resetPassword = value;
      })

      this.ResetInput('请再次输入新密码', InputType.Password, this.resetPasswordConfirm, (value: string) => {
        this.resetPasswordConfirm = value;
      })

      Button(this.resettingPassword ? '重置中...' : '确认重置密码')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#4387F5')
        .borderRadius(8)
        .enabled(!this.resettingPassword)
        .onClick(() => {
          this.confirmResetPassword();
        })

      if (this.resetMessage.length > 0) {
        Text(this.resetMessage)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(
            this.resetMessage.indexOf('已发送') >= 0 || this.resetMessage.indexOf('正在') >= 0
              ? '#16865C'
              : '#DC2626'
          )
          .textAlign(TextAlign.Center)
      }

      Button('取消')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontColor('#475569')
        .backgroundColor('#EEF2F7')
        .borderRadius(8)
        .onClick(() => {
          this.closeResetDialog();
        })
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({
      radius: 20,
      color: '#330B1B44',
      offsetX: 0,
      offsetY: 8
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.login_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column() {
        Column({ space: 14 }) {
          Text('AI For Study')
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor('#5A96D8')
            .textAlign(TextAlign.Center)

          Text('AI 赋能学习 · 智慧成就未来')
            .fontSize(20)
            .fontColor('#7A7A7A')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .margin({ top: 142 })

        Column({ space: 24 }) {
          this.LoginInput('请输入用户名', false)
          this.LoginInput('请输入密码', true)

          Row() {
            Text('忘记密码？')
              .fontSize(16)
              .fontColor('#4D8FF7')
              .onClick(() => {
                this.openResetDialog();
              })

            Blank()

            Text('立即注册  >')
              .fontSize(16)
              .fontColor('#4D8FF7')
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/RegisterPage'
                });
              })
          }
          .width('84%')

          Button(this.loading ? '登录中...' : '立即登录')
            .width('84%')
            .height(58)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .borderRadius(29)
            .backgroundColor('#4387F5')
            .enabled(!this.loading)
            .onClick(() => {
              this.doLogin();
            })

          if (this.message.length > 0) {
            Text(this.message)
              .width('84%')
              .fontSize(13)
              .fontColor(
                this.message.indexOf('成功') >= 0 || this.message.indexOf('正在') >= 0
                  ? '#2563EB'
                  : '#DC2626'
              )
              .textAlign(TextAlign.Center)
          }
        }
        .width('86%')
        .height(365)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#EFFFFFFF')
        .borderRadius(22)
        .margin({ top: 24 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)

      if (this.showResetDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#00000055')
            .onClick(() => {
              this.closeResetDialog();
            })

          this.ResetPasswordDialog()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
