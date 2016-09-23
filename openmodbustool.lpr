program OpenModBusTool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, lazcontrols, IdModbusClient, FormMain, formOptions, ThreadModBus,
  FormAbout, formBitEdit,
  { you can add units after this }
  DefaultTranslator // - forced translation
  ;

{$R *.res}

begin
  Application.Title:='OpenModBusTool';
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TfrmOptions, frmOptions);
  Application.CreateForm(TfrmAbout, frmAbout);
  Application.CreateForm(TfrmBitEdit, frmBitEdit);
  Application.Run;
end.

