// Eduardo - 04/12/2024
unit Pipa.Selecao.Arquivo;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Graphics,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.Ani,
  FMX.Layouts,
  FMX.ListBox,
  FMX.Controls.Presentation;

type
  TSelecaoArquivo = class(TFrame)
    tmrListar: TTimer;
    ListBox: TListBox;
    rtgTop: TRectangle;
    lbl_path: TLabel;
    odDialog: TOpenDialog;
    rtgVoltar: TRectangle;
    pthVoltar: TPath;
    rtgFechar: TRectangle;
    tmrFechar: TTimer;
    img_file: TImage;
    img_folder: TImage;
    pthFechar: TPath;
    rtgTodos: TRectangle;
    pthTodos: TPath;
    procedure tmrListarTimer(Sender: TObject);
    procedure rtgFecharClick(Sender: TObject);
    procedure ListBoxItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure rtgVoltarClick(Sender: TObject);
    procedure tmrFecharTimer(Sender: TObject);
    procedure rtgTodosClick(Sender: TObject);
  private
    FDirAtual: String;
    procedure MontarLista(path_tr: string; clear: boolean);
    procedure AddListItem(list: array of string; itype: string);
  public
    Selecionar: TProc<TArray<String>>;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  {$IFDEF ANDROID}
  Androidapi.Helpers,
  Androidapi.Jni.JavaTypes,
  Androidapi.Jni.Os,
  {$ENDIF}
  System.Permissions;

{$R *.fmx}

procedure TSelecaoArquivo.tmrListarTimer(Sender: TObject);
begin
  tmrListar.Enabled := False;
  {$IFDEF ANDROID}
  PermissionsService.RequestPermissions(
    [JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE), JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)],
    procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
    begin
      for var Item in AGrantResults do
      begin
        if Item <> TPermissionStatus.Granted then
        begin
          ShowMessage('Permissão negada!');
          Exit;
        end;
      end;

      // Se chegou até aqui é pq tem permissão.. deve listar os arquivos
      FDirAtual := System.IOUtils.TPath.GetSharedDocumentsPath;

      MontarLista(FDirAtual, True);
    end
  );
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  FDirAtual := ExpandUNCFileName(System.IOUtils.TPath.GetDownloadsPath +'\..\');
  MontarLista(FDirAtual, True);
  {$ENDIF}
end;

procedure TSelecaoArquivo.rtgFecharClick(Sender: TObject);
begin
  Free;
end;

procedure TSelecaoArquivo.rtgVoltarClick(Sender: TObject);
begin
  FDirAtual := ExpandUNCFileName(FDirAtual +'\..\');
  MontarLista(FDirAtual, True);
end;

procedure TSelecaoArquivo.AddListItem(list: array of string; itype: string);
var
  c: integer;
  LItem: TListBoxItem;
  BitmapFolder, BitmapFile: TBitmap;
begin
  BitmapFolder := img_folder.Bitmap;
  BitmapFile := img_file.Bitmap;

  ListBox.BeginUpdate;
  try
    for c := 0 to Length(list) - 1 do
    begin
      LItem := TListBoxItem.Create(ListBox);

      if itype = 'pasta' then
      begin
        if BitmapFolder <> nil then
          LItem.ItemData.Bitmap.Assign(BitmapFolder);
      end
      else
      begin
        if BitmapFile <> nil then
          LItem.ItemData.Bitmap.Assign(BitmapFile);
      end;

      LItem.Height := 40;
      LItem.ItemData.Text := ExtractFileName(list[c]);
      LItem.ItemData.Detail := list[c];
      LItem.TagString := itype;
      ListBox.AddObject(LItem);
    end;
  finally
    ListBox.EndUpdate;
  end;  
end;

procedure TSelecaoArquivo.MontarLista(path_tr: string; clear: boolean);
var
  folders, files: TStringDynArray;
begin
  lbl_path.Text := path_tr;

  folders := TDirectory.GetDirectories(path_tr);

  TArray.Sort<String>(
    folders, 
    TComparer<String>.Construct(
      function(const Left, Right: string): Integer
      begin
        Result := CompareStr(AnsiLowerCase(Left), AnsiLowerCase(Right));
      end
    )
  );

  if clear then
    ListBox.Clear;

  AddListItem(folders, 'pasta');

  files := TDirectory.GetFiles(path_tr);

  TArray.Sort<String>(
    files, 
    TComparer<String>.Construct(
      function(const Left, Right: string): Integer
      begin
        Result := CompareStr(AnsiLowerCase(Left), AnsiLowerCase(Right));
      end
    )
  );

  AddListItem(files, 'arquivo');

  ListBox.ScrollToItem(ListBox.ItemByIndex(0));
end;

procedure TSelecaoArquivo.ListBoxItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item.TagString = 'pasta' then
  begin
    FDirAtual := Item.ItemData.Detail;

    if TDirectory.Exists(FDirAtual) then
      MontarLista(FDirAtual, True)
    else
    begin
      ListBox.Items.Delete(Item.Index);
      ShowMessage('Não foi possível abrir a pasta selecionada');
    end;
  end
  else 
  if Item.TagString = 'arquivo' then
  begin
    Selecionar([Item.ItemData.Detail]);
    tmrFechar.Enabled := True;
  end;
end;

procedure TSelecaoArquivo.rtgTodosClick(Sender: TObject);
begin
  Selecionar(TDirectory.GetFiles(FDirAtual));
  tmrFechar.Enabled := True;
end;

procedure TSelecaoArquivo.tmrFecharTimer(Sender: TObject);
begin
  tmrFechar.Enabled := False;
  Free;
end;

end.
