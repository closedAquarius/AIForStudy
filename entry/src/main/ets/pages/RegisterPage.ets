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
  @State passwordVisible: boolean = false;

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
        AppStorage.SetOrCreate<string>('token', result.data.token ?? '');
        AppStorage.SetOrCreate<string>('currentUser', JSON.stringify(result.data.user));
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
  RegisterInput(placeholderText: string, valueType: string) {
    Row() {
      Text(valueType === 'password' ? '锁' : '人')
        .width(34)
        .fontSize(20)
        .fontColor('#9CA3AF')
        .textAlign(TextAlign.Center)

      if (valueType === 'username') {
        TextInput({ placeholder: placeholderText, text: this.username })
          .layoutWeight(1)
          .height(50)
          .fontSize(17)
          .fontColor('#1F2937')
          .placeholderColor('#B7BBC3')
          .caretColor('#4C6FFF')
          .backgroundColor('#00000000')
          .padding({ left: 8, right: 8 })
          .onChange((value: string) => {
            this.username = value;
          })
      } else if (valueType === 'nickname') {
        TextInput({ placeholder: placeholderText, text: this.nickname })
          .layoutWeight(1)
          .height(50)
          .fontSize(17)
          .fontColor('#1F2937')
          .placeholderColor('#B7BBC3')
          .caretColor('#4C6FFF')
          .backgroundColor('#00000000')
          .padding({ left: 8, right: 8 })
          .onChange((value: string) => {
            this.nickname = value;
          })
      } else {
        TextInput({ placeholder: placeholderText, text: this.password })
          .layoutWeight(1)
          .height(50)
          .type(this.passwordVisible ? InputType.Normal : InputType.Password)
          .fontSize(17)
          .fontColor('#1F2937')
          .placeholderColor('#B7BBC3')
          .caretColor('#4C6FFF')
          .backgroundColor('#00000000')
          .padding({ left: 8, right: 8 })
          .onChange((value: string) => {
            this.password = value;
          })

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
      .fontSize(24)
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
        this.doRegister();
      })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Blank()
          .height('15%')

        this.BrandHeader()

        Blank()
          .height(62)

        Column({ space: 20 }) {
          this.RegisterInput('用户名', 'username')
          this.RegisterInput('昵称（可选）', 'nickname')
          this.RegisterInput('密码', 'password')

          Blank()
            .height(30)

          Row() {

            Text('已有账号？返回登录')
              .fontSize(16)
              .fontColor('#3F66FF')
              .onClick(() => {
                router.back();
              })
          }
          .width('82%')
          .margin({ top: -2 })

          this.PrimaryButton(this.loading ? '注册中...' : '注册')

          if (this.message.length > 0) {
            Text(this.message)
              .width('82%')
              .fontSize(13)
              .fontColor(this.message.includes('成功') || this.message.includes('正在') ? '#3F66FF' : '#DC2626')
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
    }
    .width('100%')
    .height('100%')
  }
}