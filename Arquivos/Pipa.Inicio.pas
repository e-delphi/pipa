// Eduardo - 03/11/2024
unit Pipa.Inicio;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Objects,
  FMX.Layouts,
  FMX.TabControl,
  Pipa.Logo,
  Pipa.Arquivos;

type
  TInicio = class(TForm)
    tmrInicio: TTimer;
    procedure tmrInicioTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
  private
    Logo: TLogo;
    Arquivos: TArquivos;
  end;

var
  Inicio: TInicio;

implementation

{$R *.fmx}

procedure TInicio.FormCreate(Sender: TObject);
begin
  Logo := TLogo.Create(Self);
  Logo.Parent := Self;
  Logo.Align := TAlignLayout.Client;
end;

procedure TInicio.tmrInicioTimer(Sender: TObject);
begin
  tmrInicio.Enabled := False;

  Logo.Free;

  Arquivos := TArquivos.Create(Self);
  Arquivos.Parent := Self;
  Arquivos.Align := TAlignLayout.Client;
end;

procedure TInicio.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Assigned(Arquivos) then
    Arquivos.FrameKeyUp(Sender, Key, KeyChar, Shift);
end;

end.
