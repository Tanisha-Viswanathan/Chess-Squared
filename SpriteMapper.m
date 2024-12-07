function post = SpriteMapper(pre)
  if (~iseabs(pre))
    player = pre.Player;
    type = pre.Type;

    switch type
      case PieceType.Rook
        id = 6;
      case PieceType.Bishop
        id = 5;
      case PieceType.Knight
        id = 4;
      case PieceType.Queen
        id = 7;
      case PieceType.King
        id = 8;
      case PieceType.Pawn
        id = 3;
    end

    post = (player - 1) * 6 + id;
  else
    post = 99;
  end
end