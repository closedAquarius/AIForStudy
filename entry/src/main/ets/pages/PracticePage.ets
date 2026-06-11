import { router } from '@kit.ArkUI';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import {
  QuestionBankSummary,
  getQuestionBanks,
  createQuestionBank,
  updateQuestionBank,
  deleteQuestionBank
} from '../common/ApiClient';

@Entry
@Component
struct PracticePage {
  @State banks: QuestionBankSummary[] = [];
  @State loading: boolean = false;

  @State activeMenuBankId: number = -1;
  @State pressedBankId: number = -1;

  @State showBankDialog: boolean = false;
  @State dialogTitle: string = '新建题库';
  @State editingBankId: number = 0;
  @State bankNameInput: string = '';
  @State bankDescInput: string = '';

  @State showDeleteDialog: boolean = false;
  @State deletingBankId: number = 0;
  @State deletingBankName: string = '';

  aboutToAppear(): void {
  }

  onPageShow(): void {
    this.loadBanks();
  }

  private getToken(): string {
    return AppStorage.Get<string>('token') ?? '';
  }

  private showTip(message: string): void {
    AlertDialog.show({
      title: '提示',
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '知道了',
        action: () => {
        }
      }
    });
  }

  private async loadBanks(): Promise<void> {
    this.loading = true;

    try {
      const result = await getQuestionBanks(this.getToken());
      if (result.success && result.data) {
        this.banks = result.data.banks;
      } else {
        this.showTip(result.message || '题库加载失败');
      }
    } catch (error) {
      this.showTip(`题库加载失败：${(error as Error).message}`);
    } finally {
      this.loading = false;
    }
  }

  private goDetail(bank: QuestionBankSummary): void {
    this.activeMenuBankId = -1;
    router.pushUrl({
      url: 'pages/QuestionBankDetailPage',
      params: {
        bankId: bank.id.toString(),
        bankName: bank.name
      }
    });
  }

  private openCreateDialog(): void {
    this.dialogTitle = '新建题库';
    this.editingBankId = 0;
    this.bankNameInput = '';
    this.bankDescInput = '';
    this.showBankDialog = true;
  }

  private openRenameDialog(bank: QuestionBankSummary): void {
    this.activeMenuBankId = -1;

    if (!bank.canManage) {
      this.showTip('只能修改自己创建的题库');
      return;
    }

    this.dialogTitle = '修改题库名称';
    this.editingBankId = bank.id;
    this.bankNameInput = bank.name;
    this.bankDescInput = bank.description;
    this.showBankDialog = true;
  }

  private openDeleteDialog(bank: QuestionBankSummary): void {
    this.activeMenuBankId = -1;

    if (!bank.canManage) {
      this.showTip('只能删除自己创建的题库');
      return;
    }

    this.deletingBankId = bank.id;
    this.deletingBankName = bank.name;
    this.showDeleteDialog = true;
  }

  private async submitBank(): Promise<void> {
    if (this.bankNameInput.trim().length === 0) {
      this.showTip('请输入题库名称');
      return;
    }

    try {
      const token = this.getToken();

      if (this.editingBankId === 0) {
        const result = await createQuestionBank(token, this.bankNameInput.trim(), this.bankDescInput.trim());
        this.showTip(result.message);
      } else {
        const result = await updateQuestionBank(token, this.editingBankId, this.bankNameInput.trim());
        this.showTip(result.message);
      }

      this.showBankDialog = false;
      await this.loadBanks();
    } catch (error) {
      this.showTip(`操作失败：${(error as Error).message}`);
    }
  }

  private async confirmDelete(): Promise<void> {
    try {
      const result = await deleteQuestionBank(this.getToken(), this.deletingBankId);
      this.showTip(result.message);
      this.showDeleteDialog = false;
      await this.loadBanks();
    } catch (error) {
      this.showTip(`删除失败：${(error as Error).message}`);
    }
  }

  @Builder
  StatPill(value: number, label: string, color: string) {
    Column({ space: 2 }) {
      Text(value.toString())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(label)
        .fontSize(11)
        .fontColor('#7B8798')
    }
    .layoutWeight(1)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .borderRadius(16)
    .backgroundColor('#F8FBFF')
  }

  @Builder
  PopupMenu(bank: QuestionBankSummary) {
    Column() {
      Text('查看详情')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor('#0B1B44')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.activeMenuBankId = -1;
          this.goDetail(bank);
        })

      Divider()
        .color('#EEF2F7')

      Text('修改名称')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor(bank.canManage ? '#2D75FF' : '#A0AEC0')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.openRenameDialog(bank);
        })

      Divider()
        .color('#EEF2F7')

      Text('删除题库')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor(bank.canManage ? '#EF4444' : '#A0AEC0')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.openDeleteDialog(bank);
        })
    }
    .width(132)
    .padding({ top: 4, bottom: 4 })
    .borderRadius(16)
    .backgroundColor('#FFFFFFFF')
  }

  @Builder
  MoreButton(bank: QuestionBankSummary) {
    Image($r('app.media.more'))
      .width(30)
      .height(30)
      .objectFit(ImageFit.Contain)
      .padding(5)
      .borderRadius(15)
      .backgroundColor('#EEF5FF')
      .onClick(() => {
        this.activeMenuBankId = this.activeMenuBankId === bank.id ? -1 : bank.id;
      })
      .bindPopup(this.activeMenuBankId === bank.id, {
        builder: () => {
          this.PopupMenu(bank);
        },
        placement: Placement.TopRight,
        popupColor: '#FFFFFFFF',
        radius: 16,
        shadow: {
          radius: 18,
          color: '#22000000',
          offsetX: 0,
          offsetY: 8
        },
        onStateChange: (event) => {
          if (!event.isVisible) {
            this.activeMenuBankId = -1;
          }
        }
      })
  }

  @Builder
  BankCard(bank: QuestionBankSummary) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 6 }) {
          Text(bank.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')
            .maxLines(1)

          Text(bank.description.length > 0 ? bank.description : '暂无题库描述')
            .fontSize(13)
            .fontColor('#6B7280')
            .maxLines(2)
            .lineHeight(19)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(bank.subjectName)
          .fontSize(12)
          .fontColor('#2D75FF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(14)
          .backgroundColor('#EAF3FF')
      }
      .width('100%')

      Row({ space: 10 }) {
        this.StatPill(bank.totalCount, '题目', '#2D75FF')
        this.StatPill(bank.practicedCount, '已刷', '#38C98A')
        this.StatPill(bank.wrongCount, '错题', '#EF4444')
      }
      .width('100%')

      Row() {
        Text(bank.canManage ? '我创建的题库' : '公开题库')
          .fontSize(12)
          .fontColor(bank.canManage ? '#38C98A' : '#8A96AD')

        Blank()

        this.MoreButton(bank)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor('#EFFFFFFF')
    .border({ width: 1, color: '#FFFFFFFF' })
    .shadow({
      radius: 14,
      color: '#146EA8FF',
      offsetX: 0,
      offsetY: 5
    })
    .scale({
      x: this.pressedBankId === bank.id ? 0.985 : 1,
      y: this.pressedBankId === bank.id ? 0.985 : 1
    })
    .opacity(this.pressedBankId === bank.id ? 0.88 : 1)
    .animation({
      duration: 120,
      curve: Curve.EaseOut
    })
    .onClick(() => {
      this.goDetail(bank);
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedBankId = bank.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedBankId = -1;
      }
    })
  }

  @Builder
  BankDialog() {
    Column({ space: 18 }) {
      Text(this.dialogTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      TextInput({ placeholder: '请输入题库名称', text: this.bankNameInput })
        .height(48)
        .borderRadius(16)
        .backgroundColor('#F3F7FF')
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.bankNameInput = value;
        })

      if (this.editingBankId === 0) {
        TextInput({ placeholder: '请输入题库描述，可为空', text: this.bankDescInput })
          .height(48)
          .borderRadius(16)
          .backgroundColor('#F3F7FF')
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.bankDescInput = value;
          })
      }

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .borderRadius(16)
          .backgroundColor('#EEF2F7')
          .fontColor('#4B5563')
          .onClick(() => {
            this.showBankDialog = false;
          })

        Button('确定')
          .layoutWeight(1)
          .height(44)
          .borderRadius(16)
          .backgroundColor('#2D75FF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.submitBank();
          })
      }
      .width('100%')
    }
    .width('82%')
    .padding(22)
    .borderRadius(26)
    .backgroundColor('#FFFFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  DeleteDialog() {
    Column({ space: 18 }) {
      Text('删除题库')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Text(`确定删除「${this.deletingBankName}」吗？删除后该题库下的题目也会被删除。`)
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .textAlign(TextAlign.Center)

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .borderRadius(16)
          .backgroundColor('#EEF2F7')
          .fontColor('#4B5563')
          .onClick(() => {
            this.showDeleteDialog = false;
          })

        Button('删除')
          .layoutWeight(1)
          .height(44)
          .borderRadius(16)
          .backgroundColor('#EF4444')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.confirmDelete();
          })
      }
      .width('100%')
    }
    .width('82%')
    .padding(22)
    .borderRadius(26)
    .backgroundColor('#FFFFFFFF')
    .shadow({
      radius: 24,
      color: '#33000000',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  FixedTopArea() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('我的题库')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B1B44')

          Text('管理题库、导入 Excel、查看统计数据')
            .fontSize(13)
            .fontColor('#64748B')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('+ 新建题库')
          .height(42)
          .borderRadius(18)
          .fontSize(14)
          .backgroundColor('#2D75FF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.openCreateDialog();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 10 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  ListArea() {
    if (this.loading) {
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)

        Text('正在加载题库...')
          .fontSize(14)
          .fontColor('#64748B')
          .margin({ top: 10 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.banks.length === 0) {
      Column({ space: 12 }) {
        Text('暂无题库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0B1B44')

        Text('点击右上角“新建题库”开始创建')
          .fontSize(14)
          .fontColor('#64748B')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 14 }) {
        ForEach(this.banks, (bank: QuestionBankSummary) => {
          ListItem() {
            this.BankCard(bank)
          }
        }, (bank: QuestionBankSummary) => bank.id.toString())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 6, bottom: 12 })
      .scrollBar(BarState.Off)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        FeaturePageHeader({
          title: '题库刷题',
          themeColor: '#2D75FF'
        })

        this.FixedTopArea()

        Column() {
          this.ListArea()
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F6F8FC')

        FeatureBottomNav({
          selectedIndex: 1
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F8FC')

      if (this.showBankDialog || this.showDeleteDialog) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
      }

      if (this.showBankDialog) {
        this.BankDialog()
      }

      if (this.showDeleteDialog) {
        this.DeleteDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}