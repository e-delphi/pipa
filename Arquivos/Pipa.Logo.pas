// Eduardo - 26/11/2024
unit Pipa.Logo;

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
  FMX.Layouts;

type
  TLogo = class(TFrame)
    rtgFundo: TRectangle;
    lytLogo: TLayout;
    imgLogo: TImage;
    txNome: TText;
  end;

implementation

{$R *.fmx}

end.
