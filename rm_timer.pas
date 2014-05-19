unit rm_timer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RadioModule, ExtCtrls;

type

  PTimerNode = ^TTimerNode;
  TTimerNode = record
    Next: PTimerNode;
    Id: PtrUInt;
    Obj: TTimer;
  end;

  { TRadioTimer }

  TRadioTimer = class(TRadioModule)
  private
    FHead: TTimerNode;
    procedure Lock;
    procedure Unlock;
    procedure OnTimer(Sender: TObject);
    // *lock* required when call FindTimer
    function  FindTimer(const Id: PtrUInt): PTimerNode;
  protected
    procedure ProccessMessage(const Msg: TRadioMessage; var Ret: Integer); override;
    procedure CreateTimer(const Id: PtrUInt; const AInterval: Cardinal);
    procedure DeleteTimer(const Id: PtrUInt);
  end;

implementation

uses
  RadioSystem;

{ TRadioTimer }

procedure TRadioTimer.Lock;
begin
  RadioGlobalLock
end;

procedure TRadioTimer.Unlock;
begin
  RadioGlobalUnlock;
end;

procedure TRadioTimer.OnTimer(Sender: TObject);
var
  P: PTimerNode;
  T: TTimer;
  M: TRadioMessage;
begin
  T := Sender as TTimer;
  P := PTimerNode(Pointer(T.Tag));
  with M do
  begin
    Id := RadioModule.RM_TIMER;
    Sender := Self;
    ParamH := P^.Id and $FFFF;
    ParamL := T.Interval;
  end;
  RadioPostMessage(M, Cardinal(P^.Id shr 32));
end;

function TRadioTimer.FindTimer(const Id: PtrUInt): PTimerNode;
begin
  Result := FHead.Next;
  while Assigned(Result) and (Result^.Id <> Id) do Result := Result^.Next;
end;

procedure TRadioTimer.ProccessMessage(const Msg: TRadioMessage; var Ret: Integer
  );
begin
  case Msg.Id of
    RM_CREATE_TIMER:
      CreateTimer(Msg.ParamH, Cardinal(Msg.ParamL));
    RM_DELETE_TIMER:
      DeleteTimer(Msg.ParamH);
    else
      inherited ProccessMessage(Msg, Ret);
  end;
end;

procedure TRadioTimer.CreateTimer(const Id: PtrUInt; const AInterval: Cardinal);
label
  Quit;
var
  P: PTimerNode;
begin
  if AInterval = 0 then Exit;
  Lock;
  P := FindTimer(Id);
  if Assigned(P) then goto Quit;
  New(P);
  P^.Id := Id;
  P^.Next := FHead.Next;
  FHead.Next := P;
  P^.Obj := TTimer.Create(nil);
  with P^.Obj do
  begin
    Interval := AInterval;
    OnTimer := @Self.OnTimer;
    Tag := PtrInt(P);
    Enabled := True;
  end;
Quit:
  Unlock;
end;

procedure TRadioTimer.DeleteTimer(const Id: PtrUInt);
var
  P: PTimerNode;
begin
  Lock;
  P := FindTimer(Id);
  if Assigned(P) then
  begin
    P^.Obj.Free;
    FHead.Next := P^.Next;
    Dispose(P);
  end;
  Unlock;
end;

end.
