import { router } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { FeaturePageHeader } from '../components/FeaturePageHeader';
import { FeatureBottomNav } from '../components/FeatureBottomNav';
import {
  QuestionBankSummary,
  getQuestionBanks,
  createQuestionBank,
  updateQuestionBank,
  deleteQuestionBank
  ,QuestionBankFolder
  ,getQuestionBankFolders
  ,createQuestionBankFolder
  ,renameQuestionBankFolder
  ,deleteQuestionBankFolder
  ,moveQuestionBanks
  ,createQuestionBankShare
  ,claimQuestionBankShare
  ,exportQuestionBank
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
  @State folders: QuestionBankFolder[] = [];
  @State activeFolderId: number = -1;
  @State manageMode: boolean = false;
  @State selectedBankIds: number[] = [];
  @State showFolderDialog: boolean = false;
  @State editingFolderId: number = 0;
  @State folderNameInput: string = '';
  @State showMoveDialog: boolean = false;
  @State movingBankIds: number[] = [];
  @State showShareDialog: boolean = false;
  @State shareCode: string = '';
  @State shareBankName: string = '';
  @State showClaimDialog: boolean = false;
  @State claimCodeInput: string = '';
  @State exportingBankId: number = 0;
  @State showExportDialog: boolean = false;
  @State exportingBank: QuestionBankSummary | null = null;

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
      const folderResult = await getQuestionBankFolders(this.getToken());
      if (result.success && result.data) {
        this.banks = result.data.banks;
      } else {
        this.showTip(result.message || '题库加载失败');
      }
      if (folderResult.success && folderResult.data) {
        this.folders = folderResult.data.folders;
      }
    } catch (error) {
      this.showTip(`题库加载失败：${(error as Error).message}`);
    } finally {
      this.loading = false;
    }
  }

  private visibleBanks(): QuestionBankSummary[] {
    if (this.activeFolderId < 0) {
      return this.banks;
    }
    return this.banks.filter((bank: QuestionBankSummary) => bank.folderId === this.activeFolderId);
  }

  private isSelected(bankId: number): boolean {
    return this.selectedBankIds.indexOf(bankId) >= 0;
  }

  private toggleBank(bank: QuestionBankSummary): void {
    if (!bank.canManage) {
      this.showTip('共享题库不能移动到个人文件夹');
      return;
    }
    if (this.isSelected(bank.id)) {
      this.selectedBankIds = this.selectedBankIds.filter((id: number) => id !== bank.id);
    } else {
      this.selectedBankIds = [...this.selectedBankIds, bank.id];
    }
  }

  private openFolderDialog(folder?: QuestionBankFolder): void {
    this.editingFolderId = folder ? folder.id : 0;
    this.folderNameInput = folder ? folder.name : '';
    this.showFolderDialog = true;
  }

  private async submitFolder(): Promise<void> {
    if (this.folderNameInput.trim().length === 0) {
      return;
    }
    const result = this.editingFolderId > 0
      ? await renameQuestionBankFolder(this.getToken(), this.editingFolderId, this.folderNameInput.trim())
      : await createQuestionBankFolder(this.getToken(), this.folderNameInput.trim());
    this.showTip(result.message);
    if (result.success) {
      this.showFolderDialog = false;
      await this.loadBanks();
    }
  }

  private async removeFolder(folder: QuestionBankFolder): Promise<void> {
    const result = await deleteQuestionBankFolder(this.getToken(), folder.id);
    this.showTip(result.message);
    if (result.success) {
      if (this.activeFolderId === folder.id) {
        this.activeFolderId = -1;
      }
      await this.loadBanks();
    }
  }

  private openMove(bankIds: number[]): void {
    this.activeMenuBankId = -1;
    this.movingBankIds = bankIds;
    this.showMoveDialog = true;
  }

  private async confirmMove(folderId: number): Promise<void> {
    const result = await moveQuestionBanks(this.getToken(), this.movingBankIds, folderId);
    this.showTip(result.message);
    if (result.success) {
      this.showMoveDialog = false;
      this.selectedBankIds = [];
      this.manageMode = false;
      await this.loadBanks();
    }
  }

  private async shareBank(bank: QuestionBankSummary): Promise<void> {
    this.activeMenuBankId = -1;
    const result = await createQuestionBankShare(this.getToken(), bank.id);
    if (result.success && result.data) {
      this.shareCode = result.data.shareCode;
      this.shareBankName = bank.name;
      this.showShareDialog = true;
    } else {
      this.showTip(result.message);
    }
  }

  private async claimShare(): Promise<void> {
    const result = await claimQuestionBankShare(this.getToken(), this.claimCodeInput.trim());
    this.showTip(result.message);
    if (result.success) {
      this.showClaimDialog = false;
      this.claimCodeInput = '';
      await this.loadBanks();
    }
  }

  private safeFileName(name: string): string {
    return name.replace(/[\\/:*?\"<>|]/g, '_');
  }

  private openExportDialog(bank: QuestionBankSummary): void {
    this.activeMenuBankId = -1;
    this.exportingBank = bank;
    this.showExportDialog = true;
  }

  private async exportBank(bank: QuestionBankSummary, format: string): Promise<void> {
    this.activeMenuBankId = -1;
    this.showExportDialog = false;
    this.exportingBankId = bank.id;
    try {
      const data = await exportQuestionBank(this.getToken(), bank.id, format);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [`${this.safeFileName(bank.name)}.${format}`];
      const documentPicker = new picker.DocumentViewPicker(getContext(this));
      const saveUris = await documentPicker.save(options);
      if (saveUris.length === 0) {
        return;
      }
      const fileUri = saveUris[0];
      const file = fileIo.openSync(
        fileUri,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      try {
        fileIo.writeSync(file.fd, data);
      } finally {
        fileIo.closeSync(file);
      }
      this.showTip('试卷已保存，可在系统“文件”应用中查看。');
    } catch (error) {
      this.showTip(`导出失败：${(error as Error).message}`);
    } finally {
      this.exportingBankId = 0;
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

      Text('移动到文件夹')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor(bank.canManage ? '#2D75FF' : '#A0AEC0')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (bank.canManage) {
            this.openMove([bank.id]);
          }
        })

      Divider().color('#EEF2F7')

      Text('分享题库')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor(bank.canManage ? '#16A66A' : '#A0AEC0')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (bank.canManage) {
            this.shareBank(bank);
          }
        })

      Divider().color('#EEF2F7')

      Text(this.exportingBankId === bank.id ? '导出中...' : '导出试卷')
        .width(132)
        .height(40)
        .fontSize(14)
        .fontColor(bank.canManage ? '#B45309' : '#A0AEC0')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (bank.canManage) {
            this.openExportDialog(bank);
          }
        })

      Divider().color('#EEF2F7')

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
        if (this.manageMode && bank.canManage) {
          Text(this.isSelected(bank.id) ? '✓' : '')
            .width(24)
            .height(24)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .borderRadius(12)
            .backgroundColor(this.isSelected(bank.id) ? '#2D75FF' : '#DCE4F0')
            .margin({ right: 10 })
        }
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

        if (bank.folderName.length > 0) {
          Text(` · ${bank.folderName}`)
            .fontSize(12)
            .fontColor('#64748B')
        }

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
      if (this.manageMode) {
        this.toggleBank(bank);
      } else {
        this.goDetail(bank);
      }
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
  FolderDialog() {
    Column({ space: 16 }) {
      Text(this.editingFolderId > 0 ? '重命名文件夹' : '新建文件夹')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      TextInput({ placeholder: '文件夹名称', text: this.folderNameInput })
        .width('100%')
        .height(44)
        .backgroundColor('#F3F7FF')
        .borderRadius(8)
        .onChange((value: string) => {
          this.folderNameInput = value;
        })

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#EEF2F7')
          .fontColor('#475569')
          .borderRadius(8)
          .onClick(() => {
            this.showFolderDialog = false;
          })
        Button('保存')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#2D75FF')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => {
            this.submitFolder();
          })
      }
      .width('100%')
    }
    .width('82%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  MoveDialog() {
    Column({ space: 10 }) {
      Text(`移动 ${this.movingBankIds.length} 个题库`)
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Button('未分类')
        .width('100%')
        .height(42)
        .backgroundColor('#F1F5F9')
        .fontColor('#475569')
        .borderRadius(8)
        .onClick(() => {
          this.confirmMove(0);
        })

      ForEach(this.folders, (folder: QuestionBankFolder) => {
        Button(folder.name)
          .width('100%')
          .height(42)
          .backgroundColor('#EEF5FF')
          .fontColor('#2D75FF')
          .borderRadius(8)
          .onClick(() => {
            this.confirmMove(folder.id);
          })
      }, (folder: QuestionBankFolder) => folder.id.toString())

      Button('取消')
        .width('100%')
        .height(42)
        .backgroundColor('#EEF2F7')
        .fontColor('#475569')
        .borderRadius(8)
        .onClick(() => {
          this.showMoveDialog = false;
        })
    }
    .width('82%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  ShareDialog() {
    Column({ space: 14 }) {
      Text('分享题库')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Text(this.shareBankName)
        .fontSize(14)
        .fontColor('#64748B')

      Text(this.shareCode)
        .width('100%')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#16A66A')
        .textAlign(TextAlign.Center)
        .padding(14)
        .backgroundColor('#ECFDF5')
        .borderRadius(8)

      Text('让对方在题库页点击“输入分享码”即可加入。')
        .fontSize(12)
        .fontColor('#64748B')
        .textAlign(TextAlign.Center)

      Button('关闭')
        .width('100%')
        .height(42)
        .backgroundColor('#2D75FF')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .onClick(() => {
          this.showShareDialog = false;
        })
    }
    .width('82%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  ClaimDialog() {
    Column({ space: 14 }) {
      Text('加入共享题库')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      TextInput({ placeholder: '请输入分享码', text: this.claimCodeInput })
        .width('100%')
        .height(44)
        .backgroundColor('#F3F7FF')
        .borderRadius(8)
        .onChange((value: string) => {
          this.claimCodeInput = value.toUpperCase();
        })

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#EEF2F7')
          .fontColor('#475569')
          .borderRadius(8)
          .onClick(() => {
            this.showClaimDialog = false;
          })
        Button('加入')
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#16A66A')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => {
            this.claimShare();
          })
      }
      .width('100%')
    }
    .width('82%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  ExportDialog() {
    Column({ space: 14 }) {
      Text('选择导出格式')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0B1B44')

      Text(this.exportingBank ? this.exportingBank!.name : '')
        .fontSize(13)
        .fontColor('#64748B')
        .maxLines(1)

      Button('Excel 试卷')
        .width('100%')
        .height(46)
        .fontSize(14)
        .fontColor('#16794D')
        .backgroundColor('#ECFDF5')
        .borderRadius(8)
        .onClick(() => {
          if (this.exportingBank) {
            this.exportBank(this.exportingBank!, 'xlsx');
          }
        })

      Button('PDF 试卷')
        .width('100%')
        .height(46)
        .fontSize(14)
        .fontColor('#B42318')
        .backgroundColor('#FFF1F2')
        .borderRadius(8)
        .onClick(() => {
          if (this.exportingBank) {
            this.exportBank(this.exportingBank!, 'pdf');
          }
        })

      Button('取消')
        .width('100%')
        .height(42)
        .fontSize(13)
        .fontColor('#475569')
        .backgroundColor('#EEF2F7')
        .borderRadius(8)
        .onClick(() => {
          this.showExportDialog = false;
        })
    }
    .width('82%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
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

        Button(this.manageMode ? '完成' : '管理')
          .height(42)
          .borderRadius(8)
          .fontSize(13)
          .backgroundColor('#EEF5FF')
          .fontColor('#2D75FF')
          .margin({ right: 8 })
          .onClick(() => {
            this.manageMode = !this.manageMode;
            if (!this.manageMode) {
              this.selectedBankIds = [];
            }
          })

        Button('+ 新建')
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

      Scroll() {
        Row({ space: 8 }) {
          Text('全部')
            .height(34)
            .padding({ left: 14, right: 14 })
            .fontSize(13)
            .fontColor(this.activeFolderId === -1 ? '#FFFFFF' : '#475569')
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .backgroundColor(this.activeFolderId === -1 ? '#2D75FF' : '#FFFFFF')
            .onClick(() => {
              this.activeFolderId = -1;
            })

          Text('未分类')
            .height(34)
            .padding({ left: 14, right: 14 })
            .fontSize(13)
            .fontColor(this.activeFolderId === 0 ? '#FFFFFF' : '#475569')
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .backgroundColor(this.activeFolderId === 0 ? '#2D75FF' : '#FFFFFF')
            .onClick(() => {
              this.activeFolderId = 0;
            })

          ForEach(this.folders, (folder: QuestionBankFolder) => {
            Row({ space: 5 }) {
              Text(`${folder.name} ${folder.bankCount}`)
                .fontSize(13)
                .fontColor(this.activeFolderId === folder.id ? '#FFFFFF' : '#475569')

              Text('⋮')
                .fontSize(16)
                .fontColor(this.activeFolderId === folder.id ? '#FFFFFF' : '#64748B')
                .onClick(() => {
                  AlertDialog.show({
                    title: folder.name,
                    message: '请选择文件夹操作',
                    primaryButton: { value: '重命名', action: () => this.openFolderDialog(folder) },
                    secondaryButton: { value: '删除', action: () => this.removeFolder(folder) }
                  });
                })
            }
              .height(34)
              .padding({ left: 14, right: 14 })
              .borderRadius(6)
              .backgroundColor(this.activeFolderId === folder.id ? '#2D75FF' : '#FFFFFF')
              .onClick(() => {
                this.activeFolderId = folder.id;
              })
          }, (folder: QuestionBankFolder) => folder.id.toString())

          Button('+')
            .width(34)
            .height(34)
            .fontSize(20)
            .fontColor('#2D75FF')
            .backgroundColor('#EEF5FF')
            .borderRadius(6)
            .onClick(() => {
              this.openFolderDialog();
            })
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: 8 }) {
        Button('输入分享码')
          .height(34)
          .fontSize(12)
          .fontColor('#16A66A')
          .backgroundColor('#ECFDF5')
          .borderRadius(6)
          .onClick(() => {
            this.showClaimDialog = true;
          })

        if (this.manageMode && this.selectedBankIds.length > 0) {
          Button(`移动已选 ${this.selectedBankIds.length} 项`)
            .height(34)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor('#2D75FF')
            .borderRadius(6)
            .onClick(() => {
              this.openMove(this.selectedBankIds);
            })
        }
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
    } else if (this.visibleBanks().length === 0) {
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
        ForEach(this.visibleBanks(), (bank: QuestionBankSummary) => {
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

      if (this.showBankDialog || this.showDeleteDialog || this.showFolderDialog ||
        this.showMoveDialog || this.showShareDialog || this.showClaimDialog ||
        this.showExportDialog) {
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

      if (this.showFolderDialog) {
        this.FolderDialog()
      }

      if (this.showMoveDialog) {
        this.MoveDialog()
      }

      if (this.showShareDialog) {
        this.ShareDialog()
      }

      if (this.showClaimDialog) {
        this.ClaimDialog()
      }

      if (this.showExportDialog) {
        this.ExportDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
