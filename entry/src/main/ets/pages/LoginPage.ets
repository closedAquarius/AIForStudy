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
  @State passwordVisible: boolean = false;

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
  BrandHeader() {
    Column({ space: 12 }) {
      Text('AI For Study')
        .fontSize(42)
        .fontWeight(FontWeight.Bold)
        .fontColor('#5267FF')
        .textAlign(TextAlign.Center)

      Text('AI赋能学习  智慧成就未来')
        .fontSize(17)
        .fontColor('#6B7280')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }

  @Builder
  LoginInput(placeholderText: string, isPassword: boolean) {
    Row() {
      Image(isPassword ? $r('app.media.lock') : $r('app.media.user'))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Cover)

      TextInput({
        placeholder: placeholderText,
        text: isPassword ? this.password : this.username
      })
        .layoutWeight(1)
        .height(50)
        .type(isPassword && !this.passwordVisible ? InputType.Password : InputType.Normal)
        .fontSize(17)
        .fontColor('#1F2937')
        .placeholderColor('#B7BBC3')
        .caretColor('#4C6FFF')
        .backgroundColor('#00000000')
        .padding({ left: 8, right: 8 })
        .onChange((value: string) => {
          if (isPassword) {
            this.password = value;
          } else {
            this.username = value;
          }
        })

      if (isPassword) {
        Text(this.passwordVisible ? '隐藏' : '显示')
          .width(48)
          .fontSize(14)
          .fontColor('#9CA3AF')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.passwordVisible = !this.passwordVisible;
          })
      }
    }
    .width('82%')
    .height(50)
    .padding({ left: 18, right: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(13)
    .border({
      width: 1,
      color: '#E5E7EB'
    })
  }

  @Builder
  PrimaryButton(text: string) {
    Button(text)
      .width('82%')
      .height(50)
      .fontSize(20)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .borderRadius(15)
      .backgroundColor('#00000000')
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [
          ['#3F66FF', 0.0],
          ['#914CFF', 1.0]
        ]
      })
      .shadow({
        radius: 14,
        color: '#332F5BFF',
        offsetX: 0,
        offsetY: 8
      })
      .enabled(!this.loading)
      .onClick(() => {
        this.doLogin();
      })
  }

  @Builder
  ResetInput(placeholderText: string, inputType: InputType, value: string, action: (value: string) => void) {
    TextInput({ placeholder: placeholderText, text: value })
      .width('100%')
      .height(46)
      .type(inputType)
      .fontSize(14)
      .fontColor('#1F2937')
      .placeholderColor('#A8AFBC')
      .caretColor('#4C6FFF')
      .backgroundColor('#F6F7FB')
      .borderRadius(10)
      .padding({ left: 14, right: 14 })
      .onChange(action)
  }

  @Builder
  ResetPasswordDialog() {
    Column({ space: 14 }) {
      Row() {
        Text('找回密码')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .layoutWeight(1)

        Button('×')
          .width(32)
          .height(32)
          .fontSize(18)
          .fontColor('#6B7280')
          .backgroundColor('#F3F4F6')
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
        .fontColor('#6B7280')

      this.ResetInput('请输入绑定邮箱', InputType.Email, this.resetEmail, (value: string) => {
        this.resetEmail = value;
      })

      Row({ space: 8 }) {
        TextInput({ placeholder: '6 位验证码', text: this.resetCode })
          .layoutWeight(1)
          .height(46)
          .type(InputType.Number)
          .maxLength(6)
          .fontSize(14)
          .fontColor('#1F2937')
          .placeholderColor('#A8AFBC')
          .caretColor('#4C6FFF')
          .backgroundColor('#F6F7FB')
          .borderRadius(10)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.resetCode = value;
          })

        Button(
          this.sendingCode
            ? '发送中'
            : (this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
        )
          .width(106)
          .height(46)
          .fontSize(12)
          .fontColor(this.countdown > 0 ? '#9CA3AF' : '#4C6FFF')
          .backgroundColor('#EEF2FF')
          .borderRadius(10)
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
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor('#00000000')
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            ['#3F66FF', 0.0],
            ['#914CFF', 1.0]
          ]
        })
        .borderRadius(10)
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
        .height(42)
        .fontSize(14)
        .fontColor('#4B5563')
        .backgroundColor('#F3F4F6')
        .borderRadius(10)
        .onClick(() => {
          this.closeResetDialog();
        })
    }
    .width('86%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 10
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Blank()
          .height('18%')

        this.BrandHeader()

        Blank()
          .height(60)

        Column({ space: 20 }) {
          this.LoginInput('用户名', false)
          this.LoginInput('密码', true)

          Blank()
            .height(30)

          Row() {
            Text('忘记密码？')
              .fontSize(16)
              .fontColor('#6B7280')
              .onClick(() => {
                this.openResetDialog();
              })

            Blank()

            Text('立即注册  >')
              .fontSize(16)
              .fontColor('#3F66FF')
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/RegisterPage'
                });
              })
          }
          .width('82%')
          .margin({ top: -6 })

          this.PrimaryButton(this.loading ? '登录中...' : '登录')

          if (this.message.length > 0) {
            Text(this.message)
              .width('82%')
              .fontSize(13)
              .fontColor(
                this.message.indexOf('成功') >= 0 || this.message.indexOf('正在') >= 0
                  ? '#3F66FF'
                  : '#DC2626'
              )
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
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