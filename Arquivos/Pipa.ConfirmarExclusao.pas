// Eduardo - 04/11/2024
unit Pipa.ConfirmarExclusao;

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
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Objects,
  FMX.Ani;

type
  TConfirmarExclusao = class(TFrame)
    rtgFundo: TRectangle;
    rtgModal: TRectangle;
    rtgCancelar: TRectangle;
    txtCancelar: TText;
    canCancelar: TColorAnimation;
    rctUsuario: TRectangle;
    txtAcao: TText;
    rtgCriar: TRectangle;
    txtCriar: TText;
    canCriar: TColorAnimation;
    txtDescricao: TText;
    procedure rtgCancelarClick(Sender: TObject);
    procedure rtgCriarClick(Sender: TObject);
  public
    Excluir: TProc;
    Cancelar: TProc;
  end;

implementation

{$R *.fmx}

procedure TConfirmarExclusao.rtgCancelarClick(Sender: TObject);
begin
  Cancelar;
  Free;
end;

procedure TConfirmarExclusao.rtgCriarClick(Sender: TObject);
begin
  Excluir;
  Free;
end;

end.

