// Eduardo - 26/11/2024
unit Pipa.Novo;

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
  FMX.Ani,
  FMX.Objects,
  FMX.Layouts;

type
  TNovo = class(TFrame)
    rtgFundo: TRectangle;
    rtgModal: TRectangle;
    lytAdicionarArquivo: TLayout;
    lytArquivo: TLayout;
    pthArquivo: TPath;
    txtArquivo: TText;
    lytAdicionarPasta: TLayout;
    lytPasta: TLayout;
    pthPasta: TPath;
    txtPasta: TText;
    rtgCancelar: TRectangle;
    txtCancelar: TText;
    canCancelar: TColorAnimation;
    procedure lytAdicionarPastaClick(Sender: TObject);
    procedure lytAdicionarArquivoClick(Sender: TObject);
    procedure rtgCancelarClick(Sender: TObject);
  public
    Pasta: TProc;
    Arquivo: TProc;
  end;

implementation

{$R *.fmx}

procedure TNovo.lytAdicionarArquivoClick(Sender: TObject);
begin
  try
  Arquivo;
  finally
    Free;
  end;     
end;

procedure TNovo.lytAdicionarPastaClick(Sender: TObject);
begin
  try
    Pasta;
  finally
    Free;
  end;
end;

procedure TNovo.rtgCancelarClick(Sender: TObject);
begin
  Free;
end;

end.
