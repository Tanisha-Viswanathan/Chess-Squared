function piecetype = pieceprompt()
    % Define valid pieces
    valid_pieces = {'queen', 'rook', 'knight', 'bishop'};

    % Initial prompt to ask the user for input
    piece = inputdlg('What piece would you like to upgrade to? (Queen, Rook, Knight, Bishop): ', 'Upgrade Chess Piece');
    
    % Convert to lowercase and check validity
    if ~isempty(piece)
        piece = lower(piece{1});  % Convert input to lowercase

        % Check if the piece is valid
        if ismember(piece, valid_pieces)
            msgbox(['You have chosen to upgrade to a ', piece, '.'], 'Piece Upgrade');
        else
            msgbox('Invalid choice. Please choose a valid piece (Queen, Rook, Knight, or Bishop).', 'Error', 'error');
            % Call the function recursively to prompt again
            piece = pieceprompt();
        end
    else
        msgbox('No input detected. Please choose a valid piece.', 'Error', 'error');
        piece = pieceprompt();  % Call recursively if no input is given
    end

    % Get the corresponding PieceType for the string
    switch piece
        case 'queen'
            piecetype = PieceType.Queen;
        case 'rook'
            piecetype = PieceType.Rook;
        case 'knight'
            piecetype = PieceType.Knight;
        case 'bishop'
            piecetype = PieceType.Bishop;
    end
end
