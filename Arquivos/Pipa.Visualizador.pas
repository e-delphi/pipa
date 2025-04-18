// Eduardo - 06/11/2024
unit Pipa.Visualizador;

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
  FMX.Objects;

type
  TVisualizador = class(TFrame)
    rtgTop: TRectangle;
    rtgFechar: TRectangle;
    pthFechar: TPath;
    rtgSalvar: TRectangle;
    pthSalvar: TPath;
    svDialog: TSaveDialog;
    rtgFundo: TRectangle;
    procedure rtgFecharClick(Sender: TObject);
    procedure rtgSalvarClick(Sender: TObject);
  private
    FNome: String;
    FStream: TStringStream;
  public
    procedure Exibir(sNome: String; ss: TStringStream);
    destructor Destroy; override;
  end;

implementation

uses
  System.StrUtils,
  System.IOUtils,
  {$IFDEF ANDROID}
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.provider,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Net,
  Androidapi.JNI.App,
  AndroidAPI.jNI.OS,
  Androidapi.JNIBridge,
  FMX.Helpers.Android,
  IdUri,
  Androidapi.Helpers,
  FMX.Platform.Android,
  System.Permissions,
  {$ENDIF}
  Pipa.Visualizador.Imagem;

{$R *.fmx}

{ TVisualizador }

destructor TVisualizador.Destroy;
begin
  FreeAndNil(FStream);
  inherited;
end;

procedure TVisualizador.Exibir(sNome: String; ss: TStringStream);
var
  ivf: TImageViewerFrame;
  bmp: TBitmap;
begin
  FNome := sNome;
  FStream := ss;

  if MatchStr(ExtractFileExt(sNome).ToLower, ['.jpg', '.png', '.bmp']) then
  begin
    ivf := TImageViewerFrame.Create(Self);
    ivf.Parent := Self;
    ivf.Align := TAlignLayout.Client;

    bmp := TBitmap.Create;
    try
      bmp.LoadFromStream(ss);
      ivf.LoadFromBitmap(bmp);
    finally
      FreeAndNil(bmp);
    end;
  end;
end;

procedure TVisualizador.rtgFecharClick(Sender: TObject);
begin
  Free;
end;

procedure TVisualizador.rtgSalvarClick(Sender: TObject);
{$IFDEF ANDROID}
var
  Intent: JIntent;
{$ENDIF}
begin
  {$IFDEF ANDROID}
  if not PermissionsService.IsPermissionGranted(JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)) then
  begin
    PermissionsService.RequestPermissions(
      [JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE)],
      procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
      begin
        if (Length(AGrantResults) = 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
          ShowMessage('Acesso concedido!')
        else
          ShowMessage('Acesso negado!')
      end
    );
  end
  else
  begin
    FStream.SaveToFile(TPath.Combine(TPath.GetSharedDownloadsPath, FNome));

    Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_VIEW,
      TJnet_Uri.JavaClass.parse(
        TJImages_Media.JavaClass.insertImage(
          TAndroidHelper.Activity.getContentResolver,
          StringToJString(TPath.Combine(TPath.GetSharedDownloadsPath, FNome)),
          StringToJString(FNome),
          StringToJString('')
        )
      )
    );
    TAndroidHelper.Activity.startActivity(Intent);
  end;
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  svDialog.Filter := 'Original|'+ ExtractFileExt(FNome);
  svDialog.FileName := FNome;

  if not svDialog.Execute then
    Exit;

  FStream.SaveToFile(svDialog.FileName);
  {$ENDIF}
end;

end.
