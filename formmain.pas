unit FormMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, ListViewFilterEdit,
  Forms, Controls, Graphics, Dialogs, ExtCtrls, ComCtrls,
  IdComponent, IdTCPClient, fpspreadsheetgrid, StdCtrls,
  ActnList, Menus, IniPropStorage,
  ThreadModBus;

{
0x (bit, RW) - Discrete Output Coils
1x (bit, RO) - Discrete Input Contacts
3x (word, RO) - Analog Input Registers
4x ( word, RW) - Analog Output Holding Registers
}

type
  { TfrmMain }

  TfrmMain = class(TForm)
    actDissconect: TAction;
    actConnect: TAction;
    actAbout: TAction;
    actExit: TAction;
    actCopy: TAction;
    actCopyValue: TAction;
    actSet1: TAction;
    actSet0: TAction;
    actPaste: TAction;
    actOptions: TAction;
    ActionList1: TActionList;
    ApplicationProperties1: TApplicationProperties;
    btnConnect: TButton;
    btnDissconect: TButton;
    cbIP: TComboBox;
    cbRegisterType: TComboBox;
    cbRegFormat: TComboBox;
    edRegCount: TEdit;
    IdTCPClient1: TIdTCPClient;
    IniPropStorage1: TIniPropStorage;
    lbRegCount: TLabel;
    lbAddr: TLabel;
    edRegAddr: TLabeledEdit;
    listMain: TListView;
    ListViewFilterEdit1: TListViewFilterEdit;
    menuMainForm: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    mnCopyValueOnly: TMenuItem;
    mnSet1: TMenuItem;
    mnPaste: TMenuItem;
    mnSet0: TMenuItem;
    mnCopy: TMenuItem;
    Panel1: TPanel;
    Panel2: TPanel;
    menuMainList: TPopupMenu;
    rgViewStyle: TRadioGroup;
    StatusBar1: TStatusBar;
    TimerInit: TTimer;
    TimerReadMB: TTimer;
    procedure actConnectExecute(Sender: TObject);
    procedure actConnectUpdate(Sender: TObject);
    procedure actDissconectExecute(Sender: TObject);
    procedure actDissconectUpdate(Sender: TObject);
    procedure cbRegFormatChange(Sender: TObject);
    procedure cbRegisterTypeChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure rgViewStyleClick(Sender: TObject);
    procedure TimerInitTimer(Sender: TObject);
    procedure treeMainDblClick(Sender: TObject);
    procedure threadReadTerminating(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    threadRead: TThreadModBus;
    function LoadListRegs(Filename: String): boolean;
  end;

var
  frmMain: TfrmMain;

const
  // index
  idxColumnMainText = 0;
  idxColumnReg = 1;
  idxColumnValue = 2;
  idxColumnType = 3;
  idxColumnName = 4;
  idxStatusBarStatus = 0;
  idxStatusBarErrorCount = 1;
  idxStatusBarMainText = 2;

function GetBit(Value: QWord; Index: byte): boolean;
function NormalizeConfigFileName(name: string): string;

implementation

{$R *.lfm}

uses
  StrUtils,
  csvreadwrite;

{ TfrmMain }

function NormalizeConfigFileName(name: string): string;
begin
  result := name;
  if not FileExists(name) then
  begin
    // пытаемся загрузить (только если у файла не прописан путь к дириктории)
    if ExtractFileDir(name) = '' then
      if FileExists(ExtractFileDir(Application.Params[0])+'\'+name) then
        result := ExtractFileDir(Application.Params[0])+'\'+name;
  end;
end;

function GetBit(Value: QWord; Index: byte): boolean;
begin
  Result := ((Value shr Index) and 1) = 1;
end;

//////////////////////////////////////////////////////////////////////////////

procedure TfrmMain.treeMainDblClick(Sender: TObject);
begin
{  if treeMain.Selected<>nil then
  begin
    ShowMessage(
    'register='+IntToStr((DWord(treeMain.Selected.Data) div 1024))+
    ' bit='+IntToStr((DWord(treeMain.Selected.Data) mod 1024)));
  end;}
end;

function TfrmMain.LoadListRegs(Filename: String): boolean;
var
  FileStream: TFileStream;
  Parser: TCSVParser;
  row: array [0..2] of string;
  LastRow: integer;

  procedure ParsePrevRow;
  var i:TListItem;
  begin
    i:=frmMain.listMain.Items.Add;
    i.SubItems.Add(row[0]);
    i.SubItems.Add('???');
    i.SubItems.Add(row[1]);
    i.SubItems.Add(row[2]);
    //i.Caption:=i.SubItems.Text;
    i.Caption:=row[0]+'=?';
  end;

begin
  if not(FileExists(FileName)) then exit;

  try
    Parser:=TCSVParser.Create;
    FileStream := TFileStream.Create(Filename, fmOpenRead+fmShareDenyWrite);

    Parser.Delimiter:=';';
    Parser.SetSource(FileStream);

    LastRow := 1;
    while Parser.ParseNextCell do
    begin
      // Skip header row
      if (Parser.CurrentRow=0) then
        continue;

      // new row detected
      if LastRow <> Parser.CurrentRow then
      begin
        LastRow := Parser.CurrentRow;
        if row[0]<>'' then
          ParsePrevRow;
        row[0]:='';row[1]:='';row[2]:='';
      end;

      // save parsed row
      if (Parser.CurrentCol >= 1) and (Parser.CurrentCol <= 3) then
        row[Parser.CurrentCol] := Trim(Parser.CurrentCellText);
    end;
    ParsePrevRow;

    // fix bug (Laz 1.6): after load filter not update data - need reconect control
    frmMain.ListViewFilterEdit1.FilteredListview:=nil;
    frmMain.ListViewFilterEdit1.FilteredListview:=frmMain.listMain;
  finally
    FreeAndNil(Parser);
    FreeAndNil(FileStream);
  end;
end;

procedure TfrmMain.actConnectExecute(Sender: TObject);
var ip: string;
begin
  ip := Trim(cbIP.Text);
  if ip <> '' then
  begin
    threadRead := TThreadModBus.Create(false);
    actDissconect.Enabled:=true;
  end else
    cbIP.SetFocus;

  // work with history
  if (ip <> '') then
  begin
    // если нет в списке, то сохраняем команды в список
    if cbIP.Items.IndexOf(ip) = -1 then
      cbIP.Items.Insert(0, ip) else
      begin
        // если есть в списке то просто поднимаем на вверх
        cbIP.Items.Delete(cbIP.Items.IndexOf(ip));
        cbIP.Items.Insert(0, ip);
      end;
    // удаляем лишние
    while (cbIP.Items.Count > 30) do
      cbIP.Items.Delete(30);
    cbIP.Text:=ip;
  end;
end;

procedure TfrmMain.actConnectUpdate(Sender: TObject);
begin
  actConnect.Enabled := threadRead = nil;
end;

procedure TfrmMain.actDissconectExecute(Sender: TObject);
begin
  {  if not Terminated then Terminate;
    EventPauseAfterRead.SetEvent;
    WaitForThreadTerminate(Self.ThreadID, 1000);
    }

  if threadRead <> nil then
    threadRead.Terminate;
    //FreeAndNil(threadRead);
  actDissconect.Enabled:=false;
end;

procedure TfrmMain.actDissconectUpdate(Sender: TObject);
begin
  if threadRead = nil then
    actDissconect.Enabled:=false;
end;

procedure TfrmMain.cbRegFormatChange(Sender: TObject);
begin
  if threadRead <> nil then
    threadRead.EventPauseAfterRead.SetEvent;
  rgViewStyleClick(nil);
end;

procedure TfrmMain.cbRegisterTypeChange(Sender: TObject);
begin
  if listMain.ViewStyle=vsList then
    if threadRead <> nil then
      case threadRead.RegType of
        tRegBoolRO, tRegBoolRW:
          listMain.Column[idxColumnMainText].Width:=50;
        tRegWordRO, tRegWordRW:
          listMain.Column[idxColumnMainText].Width:=150;
      end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if threadRead <> nil then
    actDissconect.Execute;
end;

procedure TfrmMain.rgViewStyleClick(Sender: TObject);
begin
  case rgViewStyle.ItemIndex of
  0: begin
    listMain.ViewStyle:=vsReport;
    listMain.Column[idxColumnMainText].Width:=0;
    listMain.Column[idxColumnType].Width:=0;
    listMain.Column[idxColumnReg].Width:=100;
    listMain.Column[idxColumnValue].Width:=150;
    listMain.Column[idxColumnName].Width:=0;
  end;
  1: begin
    listMain.ViewStyle:=vsList;
    case TRegReadType(cbRegisterType.ItemIndex) of
      tRegBoolRO, tRegBoolRW:
        listMain.Column[idxColumnMainText].Width:=50;
      tRegWordRO, tRegWordRW:
        listMain.Column[idxColumnMainText].Width:=150;
    end;
  end;
  end;
end;

procedure TfrmMain.TimerInitTimer(Sender: TObject);
//var filename: string;
begin
  if frmMain.Visible then
  begin
    TimerInit.Enabled:=false;
    Application.ProcessMessages;
    // update
    rgViewStyleClick(nil);

    {if Application.ParamCount < 1 then
    begin
      //todo: WIP!
      Halt(666);
      MessageDlg('Ussage: ModBusList.exe [--ip=Host] [--list=CSVTextFileUTF8]'+#13+
        #13+
        'Example: ModBusList.exe 192.168.1.10 list.txt'+#13+
        #13+
        'constructor  [heX]  2016  www.hex.name',
        mtInformation, [mbClose], 0);
      Halt(1);
    end;}

    //todo: WIP
    {
    IdModBusClient1.Host:=Application.Params[1];
    if Application.ParamCount <= 1 then
      // load default file
      filename := ExtractFileName(Application.Params[0])+'.csv' else
      filename := NormalizeConfigFileName(Application.Params[2]);
    if Application.HasOption('c', 'autoclose') then
      AutoClose := true;
    if Application.HasOption('t', 'top') then
      frmMain.FormStyle := fsSystemStayOnTop;
    LoadListRegs(filename);
    }

  end;
end;

procedure TfrmMain.threadReadTerminating(Sender: TObject);
begin
  // thread report about death
  if threadRead <> nil then
  begin
    threadRead := nil; // just drop pointer!   (FreeOnTerminate=true, give error - very strange...)
    //FreeAndNil(threadRead); - error (FreeOnTerminate=false, but error - strange...)
  end;
  frmMain.StatusBar1.Panels[idxStatusBarStatus].Text := 'OFFLINE';
end;

end.
