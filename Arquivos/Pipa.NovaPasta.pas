// Eduardo - 04/11/2024
unit Pipa.NovaPasta;

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
  TNovaPasta = class(TFrame)
    rtgFundo: TRectangle;
    rtgModal: TRectangle;
    rtgCancelar: TRectangle;
    txtCancelar: TText;
    canCancelar: TColorAnimation;
    rctUsuario: TRectangle;
    edtNome: TEdit;
    txtAcao: TText;
    rtgCriar: TRectangle;
    txtCriar: TText;
    canCriar: TColorAnimation;
    procedure rtgCriarClick(Sender: TObject);
    procedure rtgCancelarClick(Sender: TObject);
  public
    Criar: TProc<String>;
    Cancelar: TProc;
  end;

implementation

{$R *.fmx}

procedure TNovaPasta.rtgCancelarClick(Sender: TObject);
begin
  Free;
end;

procedure TNovaPasta.rtgCriarClick(Sender: TObject);
begin
  Criar(edtNome.Text);
  Free;
end;

end.
