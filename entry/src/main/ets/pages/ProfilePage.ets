import { router } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import {
  changeProfilePassword,
  updateProfile,
  LoginUser,
  ProfileActivityItem,
  ProfileOverviewData,
  KnowledgeGraphSummary,
  getProfileOverview,
  getKnowledgeGraph
} from '../common/ApiClient';
import { APP_THEMES, AppTheme, DEFAULT_THEME_ID, getAppTheme, updateAppTheme } from '../common/Theme';

@Component
struct ProfileStatItem {
  @Prop value: string = '';
  @Prop label: string = '';
  @Prop color: string = '#0B1B44';

  build() {
    Column({ space: 5 }) {
      Text(this.value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
        .maxLines(1)

      Text(this.label)
        .fontSize(11)
        .fontColor(getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined).textSecondary)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(76)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined).surfaceBackground)
    .borderRadius(8)
    .border({ width: 1, color: getAppTheme(AppStorage.Get<string>('appThemeId') ?? undefined).border })
  }
}

@Entry
@Component
struct ProfilePage {
  @StorageLink('appThemeId') themeId: string = DEFAULT_THEME_ID;
  @State username: string = '';
  @State nickname: string = '';
  @State email: string = '';
  @State role: string = 'student';
  @State avatarUrl: string = 'ailearning_icon.png';
  @State loading: boolean = false;
  @State overviewVersion: number = 0;
  @State errorMessage: string = '';
  @State showEditDialog: boolean = false;
  @State savingProfile: boolean = false;
  @State changingPassword: boolean = false;
  @State editNickname: string = '';
  @State editEmail: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State editMessage: string = '';
  @State selectedAvatarPath: string = '';
  @State selectedAvatarName: string = '';

  @State totalAnswers: number = 0;
  @State correctAnswers: number = 0;
  @State currentWrongCount: number = 0;
  @State accuracyRate: number = 0;
  @State sessionCount: number = 0;
  @State studyMinutes: number = 0;
  @State diaryCount: number = 0;
  @State averageMood: number = 0;
  @State ownedBankCount: number = 0;
  @State availableBankCount: number = 0;
  @State ownedQuestionCount: number = 0;
  @State aiGeneratedQuestionCount: number = 0;
  @State documentCount: number = 0;
  @State aiConversationCount: number = 0;
  @State recentActivity: ProfileActivityItem[] = [];
  @State evaluation: string = '完成练习后，这里会生成学习评价。';
  @State graphSummary: KnowledgeGraphSummary = {
    totalCount: 0,
    masteredCount: 0,
    learningCount: 0,
    weakCount: 0,
    unlearnedCount: 0
  };
  @State overviewData: ProfileOverviewData = {
    totalAnswers: 0,
    correctAnswers: 0,
    wrongAnswers: 0,
    currentWrongCount: 0,
    accuracyRate: 0,
    sessionCount: 0,
    studyMinutes: 0,
    diaryCount: 0,
    averageMood: 0,
    ownedBankCount: 0,
    availableBankCount: 0,
    ownedQuestionCount: 0,
    aiGeneratedQuestionCount: 0,
    documentCount: 0,
    aiConversationCount: 0,
    recentActivity: [],
    evaluation: '完成练习后，这里会生成学习评价。'
  };

  aboutToAppear(): void {
    this.loadUser();
    this.loadOverview();
    this.loadGraphSummary();
  }

  onPageShow(): void {
    this.loadUser();
    this.loadOverview();
    this.loadGraphSummary();
  }

  private async loadGraphSummary(): Promise<void> {
    const token = AppStorage.Get<string>('token') ?? '';
    if (token.length === 0) return;
    try {
      const result = await getKnowledgeGraph(token);
      if (result.success && result.data) {
        this.graphSummary = result.data.summary;
      }
    } catch (_) {
    }
  }

  onBackPress(): boolean {
    if (this.showEditDialog) {
      this.closeEditDialog();
      return true;
    }
    return false;
  }

  private loadUser(): void {
    const userText = AppStorage.Get<string>('currentUser') ?? '';
    if (userText.length === 0) {
      return;
    }

    try {
      const user = JSON.parse(userText) as LoginUser;
      this.username = user.username;
      this.nickname = user.nickname || user.username;
      this.email = user.email || '';
      this.role = user.role;
      this.avatarUrl = user.avatarUrl || 'ailearning_icon.png';
    } catch (error) {
      this.username = '';
    }
  }

  private async loadOverview(): Promise<void> {
    if (this.loading) {
      return;
    }

    const token = AppStorage.Get<string>('token') ?? '';
    if (token.length === 0) {
      this.errorMessage = '登录信息已失效，请重新登录。';
      return;
    }

    this.loading = true;
    this.errorMessage = '';
    try {
      const result = await getProfileOverview(token);
      if (result.success && result.data) {
        this.applyOverview(result.data);
      } else {
        this.errorMessage = result.message || '学习数据加载失败';
      }
    } catch (error) {
      this.errorMessage = `学习数据加载失败：${(error as Error).message}`;
    } finally {
      this.loading = false;
    }
  }

  private applyOverview(data: ProfileOverviewData): void {
    const nextData: ProfileOverviewData = {
      totalAnswers: Number(data.totalAnswers ?? 0),
      correctAnswers: Number(data.correctAnswers ?? 0),
      wrongAnswers: Number(data.wrongAnswers ?? 0),
      currentWrongCount: Number(data.currentWrongCount ?? 0),
      accuracyRate: Number(data.accuracyRate ?? 0),
      sessionCount: Number(data.sessionCount ?? 0),
      studyMinutes: Number(data.studyMinutes ?? 0),
      diaryCount: Number(data.diaryCount ?? 0),
      averageMood: Number(data.averageMood ?? 0),
      ownedBankCount: Number(data.ownedBankCount ?? 0),
      availableBankCount: Number(data.availableBankCount ?? 0),
      ownedQuestionCount: Number(data.ownedQuestionCount ?? 0),
      aiGeneratedQuestionCount: Number(data.aiGeneratedQuestionCount ?? 0),
      documentCount: Number(data.documentCount ?? 0),
      aiConversationCount: Number(data.aiConversationCount ?? 0),
      recentActivity: data.recentActivity ?? [],
      evaluation: data.evaluation || '完成练习后，这里会生成学习评价。'
    };
    this.overviewData = nextData;
    
    this.totalAnswers = nextData.totalAnswers;
    this.correctAnswers = nextData.correctAnswers;
    this.currentWrongCount = nextData.currentWrongCount;
    this.accuracyRate = nextData.accuracyRate;
    this.sessionCount = nextData.sessionCount;
    this.studyMinutes = nextData.studyMinutes;
    this.diaryCount = nextData.diaryCount;
    this.averageMood = nextData.averageMood;
    this.ownedBankCount = nextData.ownedBankCount;
    this.availableBankCount = nextData.availableBankCount;
    this.ownedQuestionCount = nextData.ownedQuestionCount;
    this.aiGeneratedQuestionCount = nextData.aiGeneratedQuestionCount;
    this.documentCount = nextData.documentCount;
    this.aiConversationCount = nextData.aiConversationCount;
    this.recentActivity = nextData.recentActivity;
    this.evaluation = nextData.evaluation;
    this.overviewVersion += 1;
  }

  private roleText(): string {
    if (this.role === 'teacher') {
      return '教师';
    }
    if (this.role === 'admin') {
      return '管理员';
    }
    return '学生';
  }

  private studyTimeText(): string {
    if (this.studyMinutes < 60) {
      return `${this.studyMinutes} 分钟`;
    }
    const hours = Math.floor(this.studyMinutes / 60);
    const minutes = this.studyMinutes % 60;
    return minutes > 0 ? `${hours} 小时 ${minutes} 分` : `${hours} 小时`;
  }

  private maxActivityCount(): number {
    let maxCount = 1;
    this.recentActivity.forEach((item: ProfileActivityItem) => {
      if (item.count > maxCount) {
        maxCount = item.count;
      }
    });
    return maxCount;
  }

  private activityHeight(count: number): number {
    if (count <= 0) {
      return 4;
    }
    return Math.max(12, Math.round(count * 76 / this.maxActivityCount()));
  }

  private theme() {
    return getAppTheme(this.themeId);
  }

  private changeTheme(themeId: string): void {
    const theme = updateAppTheme(themeId);
    this.themeId = theme.id;
  }

  private logout(): void {
    AppStorage.SetOrCreate<string>('token', '');
    AppStorage.SetOrCreate<string>('currentUser', '');
    router.replaceUrl({
      url: 'pages/LoginPage'
    });
  }

  private openEditDialog(): void {
    this.editNickname = this.nickname;
    this.editEmail = this.email;
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmPassword = '';
    this.editMessage = '';
    this.selectedAvatarPath = '';
    this.selectedAvatarName = '';
    this.showEditDialog = true;
  }

  private closeEditDialog(): void {
    if (!this.savingProfile && !this.changingPassword) {
      this.showEditDialog = false;
    }
  }

  private fileNameFromUri(uri: string): string {
    const cleanUri = uri.split('?')[0];
    const slashIndex = cleanUri.lastIndexOf('/');
    const name = slashIndex >= 0 ? cleanUri.substring(slashIndex + 1) : cleanUri;
    return decodeURIComponent(name);
  }

  private fileSuffix(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    return dotIndex >= 0 ? fileName.substring(dotIndex).toLowerCase() : '.jpg';
  }

  private async chooseAvatar(): Promise<void> {
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.png', '.jpg', '.jpeg', '.webp'];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select(options);
      if (result.length === 0) {
        return;
      }

      const sourceUri = result[0];
      const sourceName = this.fileNameFromUri(sourceUri);
      const cachePath = `${getContext(this).cacheDir}/avatar-${new Date().getTime()}${this.fileSuffix(sourceName)}`;
      const sourceFile = fileIo.openSync(sourceUri);
      const cacheFile = fileIo.openSync(cachePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.copyFileSync(sourceFile.fd, cacheFile.fd);
      fileIo.closeSync(sourceFile);
      fileIo.closeSync(cacheFile);
      this.selectedAvatarPath = cachePath;
      this.selectedAvatarName = sourceName;
      this.editMessage = '已选择新头像，保存资料后生效。';
    } catch (error) {
      this.editMessage = `头像选择失败：${(error as Error).message}`;
    }
  }

  private async saveProfile(): Promise<void> {
    if (this.savingProfile || this.editNickname.trim().length === 0) {
      this.editMessage = '昵称不能为空。';
      return;
    }

    this.savingProfile = true;
    this.editMessage = '正在保存个人资料...';
    try {
      const result = await updateProfile(
        AppStorage.Get<string>('token') ?? '',
        this.editNickname.trim(),
        this.editEmail.trim(),
        this.selectedAvatarPath,
        this.selectedAvatarName
      );
      if (result.success && result.data) {
        const user = result.data.user;
        AppStorage.SetOrCreate<string>('currentUser', JSON.stringify(user));
        this.nickname = user.nickname;
        this.email = user.email || '';
        this.avatarUrl = user.avatarUrl || 'ailearning_icon.png';
        this.selectedAvatarPath = '';
        this.selectedAvatarName = '';
        this.editMessage = '个人资料保存成功。';
        this.showEditDialog = false;
      } else {
        this.editMessage = result.message || '个人资料保存失败';
      }
    } catch (error) {
      this.editMessage = `个人资料保存失败：${(error as Error).message}`;
    } finally {
      this.savingProfile = false;
    }
  }

  private async savePassword(): Promise<void> {
    if (this.changingPassword) {
      return;
    }
    if (this.oldPassword.length === 0 || this.newPassword.length < 6) {
      this.editMessage = '请输入原密码，新密码至少需要 6 个字符。';
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.editMessage = '两次输入的新密码不一致。';
      return;
    }

    this.changingPassword = true;
    this.editMessage = '正在修改密码...';
    try {
      const result = await changeProfilePassword(
        AppStorage.Get<string>('token') ?? '',
        this.oldPassword,
        this.newPassword
      );
      if (result.success) {
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.editMessage = '密码修改成功。';
        this.showEditDialog = false;
      } else {
        this.editMessage = result.message || '密码修改失败';
      }
    } catch (error) {
      this.editMessage = `密码修改失败：${(error as Error).message}`;
    } finally {
      this.changingPassword = false;
    }
  }

  @Builder
  Avatar() {
    if (this.avatarUrl.length === 0 || this.avatarUrl === 'ailearning_icon.png') {
      Image($r('app.media.ailearning_icon'))
        .width(72)
        .height(72)
        .objectFit(ImageFit.Cover)
        .borderRadius(36)
    } else {
      Image(this.avatarUrl)
        .width(72)
        .height(72)
        .objectFit(ImageFit.Cover)
        .borderRadius(36)
    }
  }

  @Builder
  AccuracySection() {
    Column({ space: 12 }) {
      Row() {
        Text('答题正确率')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')
          .layoutWeight(1)

        Text(`${this.accuracyRate.toFixed(1)}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D75FF')
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(10)
          .borderRadius(5)
          .backgroundColor('#E8EEF8')

        Row()
          .width(`${Math.max(0, Math.min(100, this.accuracyRate))}%`)
          .height(10)
          .borderRadius(5)
          .backgroundColor('#2D75FF')
      }
      .width('100%')
      .height(10)

      Row() {
        Text(`正确 ${this.correctAnswers} 题`)
          .fontSize(12)
          .fontColor('#16A66A')
          .layoutWeight(1)

        Text(`待复习 ${this.currentWrongCount} 题`)
          .fontSize(12)
          .fontColor('#E05252')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#E5EAF3' })
  }

  @Builder
  ActivitySection() {
    Column({ space: 14 }) {
      Text('最近 7 天答题')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      if (this.recentActivity.length === 0) {
        Text('暂无近期答题记录')
          .width('100%')
          .height(90)
          .fontSize(13)
          .fontColor('#94A3B8')
          .textAlign(TextAlign.Center)
      } else {
        Row({ space: 8 }) {
          ForEach(this.recentActivity, (item: ProfileActivityItem) => {
            Column({ space: 5 }) {
              Text(`${item.count}`)
                .fontSize(10)
                .fontColor('#64748B')

              Column()
                .width(18)
                .height(this.activityHeight(item.count))
                .borderRadius(4)
                .backgroundColor(item.count > 0 ? '#46C99B' : '#E8EEF3')

              Text(item.label)
                .fontSize(9)
                .fontColor('#7B879D')
                .maxLines(1)
            }
            .layoutWeight(1)
            .height(112)
            .justifyContent(FlexAlign.End)
          }, (item: ProfileActivityItem) => item.date)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#E5EAF3' })
  }

  @Builder
  LearningAssetsSection(version: number) {
    Column({ space: 10 }) {
      Text('学习资产')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Row({ space: 10 }) {
        ProfileStatItem({ value: `${this.ownedBankCount}`, label: '我的题库', color: '#2D75FF' })
        ProfileStatItem({ value: `${this.availableBankCount}`, label: '可用题库', color: '#16A66A' })
      }
      .width('100%')

      Row({ space: 10 }) {
        ProfileStatItem({ value: `${this.ownedQuestionCount}`, label: '题库题目', color: '#7C5CE7' })
        ProfileStatItem({ value: `${this.aiGeneratedQuestionCount}`, label: 'AI 生成题', color: '#EC7A3D' })
      }
      .width('100%')

      Row({ space: 10 }) {
        ProfileStatItem({ value: `${this.documentCount}`, label: '上传资料', color: '#0EA5A5' })
        ProfileStatItem({ value: `${this.aiConversationCount}`, label: 'AI 会话', color: '#E05252' })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F8FAFD')
    .borderRadius(8)
    .border({ width: 1, color: '#DCE4F0' })
    .id(`learning-assets-${version}`)
  }

  @Builder
  DiaryStatsSection(version: number) {
    Row({ space: 10 }) {
      ProfileStatItem({ value: `${this.diaryCount}`, label: '日记天数', color: '#7C5CE7' })
      ProfileStatItem({
        value: this.diaryCount > 0 ? `${this.averageMood.toFixed(1)}/10` : '--',
        label: '平均心情',
        color: '#EC7A3D'
      })
    }
    .width('100%')
    .id(`diary-stats-${version}`)
  }

  @Builder
  EvaluationSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('AI')
          .width(32)
          .height(24)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().accentContrast)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.theme().accent)
          .borderRadius(6)

        Text('学习评价')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
      }
      .width('100%')

      Text(this.evaluation)
        .width('100%')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.theme().textSecondary)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme().secondarySurface)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().border })
  }

  @Builder
  KnowledgeMasterySection() {
    Column({ space: 12 }) {
      Row() {
        Text('知识掌握')
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme().textPrimary)
        Blank()
        Text('查看图谱 >').fontSize(12).fontColor('#2D75FF')
      }
      .width('100%')
      Row({ space: 8 }) {
        ProfileStatItem({ value: `${this.graphSummary.masteredCount}`, label: '已掌握', color: '#16A66A' })
        ProfileStatItem({ value: `${this.graphSummary.learningCount}`, label: '学习中', color: '#2D75FF' })
        ProfileStatItem({ value: `${this.graphSummary.weakCount}`, label: '薄弱', color: '#EF4444' })
      }
      .width('100%')
      Text(this.graphSummary.totalCount > 0
        ? `共 ${this.graphSummary.totalCount} 个知识点，仍有 ${this.graphSummary.unlearnedCount} 个尚未形成学习记录。`
        : '题目设置知识点后，这里会生成掌握图谱。')
        .width('100%').fontSize(12).lineHeight(18).fontColor(this.theme().textSecondary)
    }
    .width('100%').padding(16).backgroundColor(this.theme().surfaceBackground)
    .borderRadius(8).border({ width: 1, color: this.theme().border })
    .onClick(() => router.pushUrl({ url: 'pages/KnowledgeGraphPage' }))
  }

  @Builder
  EditAvatarPreview() {
    if (this.selectedAvatarPath.length > 0) {
      Image(this.selectedAvatarPath)
        .width(64)
        .height(64)
        .objectFit(ImageFit.Cover)
        .borderRadius(32)
    } else if (this.avatarUrl.length === 0 || this.avatarUrl === 'ailearning_icon.png') {
      Image($r('app.media.ailearning_icon'))
        .width(64)
        .height(64)
        .objectFit(ImageFit.Cover)
        .borderRadius(32)
    } else {
      Image(this.avatarUrl)
        .width(64)
        .height(64)
        .objectFit(ImageFit.Cover)
        .borderRadius(32)
    }
  }

  @Builder
  EditProfileDialog() {
    Column({ space: 14 }) {
      Row() {
        Text('编辑个人资料')
          .fontSize(18)
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
            this.closeEditDialog();
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 14 }) {
            this.EditAvatarPreview()

            Column({ space: 5 }) {
              Button('选择新头像')
                .height(36)
                .fontSize(13)
                .fontColor('#2563EB')
                .backgroundColor('#EEF5FF')
                .borderRadius(8)
                .onClick(() => {
                  this.chooseAvatar();
                })

              Text(this.selectedAvatarName.length > 0 ? this.selectedAvatarName : '支持 PNG、JPG、WEBP')
                .fontSize(10)
                .fontColor('#64748B')
                .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          TextInput({ placeholder: '昵称', text: this.editNickname })
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#F4F6FA')
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.editNickname = value;
            })

          TextInput({ placeholder: '邮箱', text: this.editEmail })
            .width('100%')
            .height(44)
            .fontSize(14)
            .type(InputType.Email)
            .backgroundColor('#F4F6FA')
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.editEmail = value;
            })

          Button(this.savingProfile ? '保存中...' : '保存个人资料')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(8)
            .enabled(!this.savingProfile)
            .onClick(() => {
              this.saveProfile();
            })

          Divider()
            .color('#E5EAF3')
            .margin({ top: 4, bottom: 2 })

          Text('修改密码')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          TextInput({ placeholder: '原密码', text: this.oldPassword })
            .width('100%')
            .height(44)
            .type(InputType.Password)
            .fontSize(14)
            .backgroundColor('#F4F6FA')
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.oldPassword = value;
            })

          TextInput({ placeholder: '新密码，至少 6 位', text: this.newPassword })
            .width('100%')
            .height(44)
            .type(InputType.Password)
            .fontSize(14)
            .backgroundColor('#F4F6FA')
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.newPassword = value;
            })

          TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
            .width('100%')
            .height(44)
            .type(InputType.Password)
            .fontSize(14)
            .backgroundColor('#F4F6FA')
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.confirmPassword = value;
            })

          Button(this.changingPassword ? '修改中...' : '修改密码')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7C3AED')
            .backgroundColor('#F3EEFF')
            .borderRadius(8)
            .enabled(!this.changingPassword)
            .onClick(() => {
              this.savePassword();
            })

          if (this.editMessage.length > 0) {
            Text(this.editMessage)
              .width('100%')
              .fontSize(12)
              .lineHeight(18)
              .fontColor(
                this.editMessage.includes('成功') || this.editMessage.includes('已选择')
                  ? '#16865C'
                  : '#DC2626'
              )
              .textAlign(TextAlign.Center)
          }

          Button('取消并关闭')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontColor('#475569')
            .backgroundColor('#EEF2F7')
            .borderRadius(8)
            .enabled(!this.savingProfile && !this.changingPassword)
            .onClick(() => {
              this.closeEditDialog();
            })
        }
        .width('100%')
      }
      .width('100%')
      .height(500)
    }
    .width('88%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .shadow({
      radius: 20,
      color: '#330B1B44',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  ThemeSection() {
    Column({ space: 12 }) {
      Text('界面主题')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().textPrimary)

      Text('可以切换黑夜模式、护眼模式、夏日清爽和冬日暖阳。')
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.theme().textSecondary)

      ForEach(APP_THEMES, (item: AppTheme) => {
        Row({ space: 12 }) {
          Row({ space: 6 }) {
            Circle().width(12).height(12).fill(item.accent)
            Circle().width(12).height(12).fill(item.pageBackground)
            Circle().width(12).height(12).fill(item.warning)
          }
          .width(54)

          Column({ space: 2 }) {
            Text(item.name)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().textPrimary)
            Text(item.description)
              .fontSize(11)
              .fontColor(this.theme().textSecondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.themeId === item.id ? '当前使用' : '切换')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeId === item.id ? item.accentContrast : item.accent)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.themeId === item.id ? item.accent : item.accentSoft)
            .borderRadius(12)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.themeId === item.id ? this.theme().secondarySurface : this.theme().surfaceBackground)
        .borderRadius(10)
        .border({ width: 1.5, color: this.themeId === item.id ? item.accent : this.theme().border })
        .onClick(() => {
          this.changeTheme(item.id);
        })
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme().surfaceBackground)
    .borderRadius(8)
    .border({ width: 1, color: this.theme().border })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      Row() {
        Button('<')
          .width(38)
          .height(38)
          .fontSize(22)
          .fontColor(this.theme().accent)
          .backgroundColor(this.theme().accentSoft)
          .borderRadius(19)
          .onClick(() => {
            router.back();
          })

        Text('个人主页')
          .layoutWeight(1)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().textPrimary)
          .textAlign(TextAlign.Center)

        Blank()
          .width(38)
      }
      .width('100%')
      .height(62)
      .padding({ left: 18, right: 18, top: 8 })
      .backgroundColor(this.theme().surfaceBackground)

      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 14 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle()
                .width(84)
                .height(84)
                .fill(this.theme().accentSoft)

              this.Avatar()
            }

            Column({ space: 5 }) {
              Text(this.nickname.length > 0 ? this.nickname : '用户')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().textPrimary)

              Text(`@${this.username.length > 0 ? this.username : 'user'}`)
                .fontSize(13)
                .fontColor(this.theme().textMuted)

              Text(`${this.roleText()}${this.email.length > 0 ? ` · ${this.email}` : ''}`)
                .fontSize(12)
                .fontColor(this.theme().textSecondary)
                .maxLines(1)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ top: 18, bottom: 8 })
          .onClick(() => {
            this.openEditDialog();
          })

          Button('查看我的错题本')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#EF4444')
            .backgroundColor('#FFF1F2')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/WrongQuestionBookPage'
              });
            })

          Button('查看我的收藏')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B45309')
            .backgroundColor('#FFF7E6')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/FavoriteQuestionPage'
              });
            })

          this.ThemeSection()

          if (this.loading) {
            Text('正在加载学习数据...')
              .width('100%')
              .fontSize(13)
              .fontColor('#64748B')
              .textAlign(TextAlign.Center)
          }

          if (this.errorMessage.length > 0) {
            Text(this.errorMessage)
              .width('100%')
              .fontSize(13)
              .fontColor('#DC2626')
              .textAlign(TextAlign.Center)
          }

          Row({ space: 10 }) {
            ProfileStatItem({ value: `${this.totalAnswers}`, label: '累计答题', color: '#2D75FF' })
            ProfileStatItem({ value: `${this.currentWrongCount}`, label: '当前错题', color: '#E05252' })
          }
          .width('100%')

          Row({ space: 10 }) {
            ProfileStatItem({ value: `${this.sessionCount}`, label: '练习次数', color: '#16A66A' })
            ProfileStatItem({ value: this.studyTimeText(), label: '学习时长', color: '#F59E0B' })
          }
          .width('100%')

          this.AccuracySection()
          this.ActivitySection()
          this.KnowledgeMasterySection()

          Column({ space: 10 }) {
            Text('学习资产')
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0B1B44')

            Row({ space: 10 }) {
              ProfileStatItem({ value: `${this.ownedBankCount}`, label: '我的题库', color: '#2D75FF' })
              ProfileStatItem({ value: `${this.availableBankCount}`, label: '可用题库', color: '#16A66A' })
            }
            .width('100%')

            Row({ space: 10 }) {
              ProfileStatItem({ value: `${this.ownedQuestionCount}`, label: '题库题目', color: '#7C5CE7' })
              ProfileStatItem({ value: `${this.aiGeneratedQuestionCount}`, label: 'AI 生成题', color: '#EC7A3D' })
            }
            .width('100%')

            Row({ space: 10 }) {
              ProfileStatItem({ value: `${this.documentCount}`, label: '上传资料', color: '#0EA5A5' })
              ProfileStatItem({ value: `${this.aiConversationCount}`, label: 'AI 会话', color: '#E05252' })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F8FAFD')
          .borderRadius(8)
          .border({ width: 1, color: '#DCE4F0' })

          Row({ space: 10 }) {
            ProfileStatItem({ value: `${this.diaryCount}`, label: '日记天数', color: '#7C5CE7' })
            ProfileStatItem({
              value: this.diaryCount > 0 ? `${this.averageMood.toFixed(1)}/10` : '--',
              label: '平均心情',
              color: '#EC7A3D'
            })
          }
          .width('100%')

          this.EvaluationSection()

          Button('退出登录')
            .width('100%')
            .height(48)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#DC2626')
            .backgroundColor('#FFF1F2')
            .borderRadius(8)
            .onClick(() => {
              this.logout();
            })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 24 })
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(this.theme().pageBackground)
      }
      .width('100%')
      .height('100%')

      if (this.showEditDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#00000055')
            .onClick(() => {
              this.closeEditDialog();
            })

          this.EditProfileDialog()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
