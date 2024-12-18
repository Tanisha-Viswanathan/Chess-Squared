classdef ChessBoard < handle
    properties
        pcounts
        % Piece counts; for optimisation purposes.

        ccounts
        % Capture counts; to save speed captures will have their enigmas
        % cleared (if you are doing capture recovery).

        Checks
        % [whitestatus, blackstatus]
        % Testing checkiness / checkmateness is computationally expensive
        % (~3ms) so automagically updates checkmate status after moves
        % internally rather than depending on [CHESS PROGRAM] to do so.

        Board
        % This is an 8x8 matrix that can either have 0 (empty) or ChessPieces.
        % It is something called a cell array, which looks something like
        % this: {0, 0, ChessPiece, 0, ChessPiece}.

        % You can access an item in a cell array like regular arrays, just
        % use {} instead of (). So something like "board{3,5}" to get 5th
        % piece on 3rd row.

        % If you try to use "board(3,5)" to get an item it will give you a
        % cell array of just that item instead ({ChessPiece} or {0}), which you can't really do anything with.
    end

    methods
        function obj = ChessBoard(preset)
            if nargin == 0
                preset = BoardPreset.Standard;
            end
            
            % Below, the board is organized like so:
            % _________________
            % |_|_|_|_|_|_|_|_|  1
            % |_|_|_|_|_|_|_|_|  2
            % |_|_|_|_|_|_|_|_|  3
            % |_|_|_|_|_|_|_|_|  4
            % |_|_|_|_|_|_|_|_|  5
            % |_|_|_|_|_|_|_|_|  6
            % |_|_|_|_|_|_|_|_|  7
            % |_|_|_|_|_|_|_|_|  8
            %  1 2 3 4 5 6 7 8
            %
            % ...where the black pieces are in rows 1-2 and white in rows
            % 7-8.
            %
            % This is also why it's a cell array; with regular array you
            % can't use both ChessPiece and numbers — so [0, ChessPiece, 0]
            % won't work.
            %
            % You can access this matrix directly using something like
            % "board = cb.Board"
            
            % Pass in '-' to forcibly not set board.
            obj.bset(preset);
            

               % Update check status (there is a chance initial layout
               % may already create check); initialise first to avoid
               % indexing issue in checkcheck().
               obj.Checks = [0,0];
               obj.checkcheck();

               % Update pcount and ccount.
               %          P  N  B  R  Q  K  p  n  b  r  q  k
               pcount = [ 0, 0, 0, 0, 0, 0; 0, 0, 0, 0, 0, 0 ];
               ccount = [ 0, 0, 0, 0, 0, 0; 0, 0, 0, 0, 0, 0 ];

               bsize = size(obj.Board);

               for r = 1:bsize(1)
                   for c = 1:bsize(2)
                       piece = obj.get([r,c]);
                       
                       if ~iseabs(piece)
                           pcount(piece.Player, abs(piece.rank())) = pcount(piece.Player, abs(piece.rank())) + 1;
                       end
                   end
               end
        end

        % "Copy"
        % Makes a copy of this object (just board and checks).
        function board = cpy(obj)
            board = ChessBoard(obj.Board);
        end

        % "Set board up"
        % Due to ChessPiece extending handle, there is no easy way to
        % create new boards without using .cpy() which clutters things
        % visually. Thus this method simply takes a cell array of the
        % template pieces and makes copies accordingly.
        %
        % preset may be a preset handle (BoardPreset.*) or the raw preset
        % itself ({...})
        function bset(obj, preset)
            % Get applied preset
            if ~isa(preset, "BoardPreset")
                aps = preset;
            else
                aps = BoardPreset.apply(preset);
            end

            % Get dims
            psize = size(aps);
            
            % Create board
            obj.Board = cell(psize);
 
            for i = 1:psize(1)
                for j = 1:psize(2)
                    piece = aps{i,j};

                    if iseabs(piece)
                        obj.Board(i,j) = { 0 };
                    else
                        obj.Board(i,j) = { piece.fcpy() };
                    end
                end
            end
        end

        %
        % "Forsyth-Edwards Notation"
        % Note this is FEN for only the starting position. Since ChessBoard
        % does not store any data about the game itself (current player, #
        % of turns, etc.) it is impossible to get a FEN beyond
        % initialisation.
        %
        % This is mainly handy for PGN and weird formats such as Chess960.
        %
        function rep = fen(obj)
            bsize = size(obj.Board);
            rbuffer = Buffer(32);

            % Loop through all pieces
            for i = 1:bsize(1)
                for j = 1:bsize(2)
                    piece = obj.get([i,j]);
                    rpool = rbuffer.pool();

                    % Increment empty space in buffer, otherwise get FEN
                    % mapping.
                    if iseabs(piece)
                        if ~isempty(rpool) && isnumeric(rpool{end})
                            rbuffer.Pool{length(rpool)} = rpool{end} + 1;
                        else
                            rbuffer.a(1);
                        end
                    else
                        rbuffer.a(fenMapper(piece));
                    end
                end
                
                % Omit if at last row.
                if i < bsize(1)
                    rbuffer.a('/');
                end
            end

            % Flush and convert piece cellarr to str.
            rep = cell2str(rbuffer.flush());

            % Add other flags...
            % Current turn? (default to White)
            rep = rep + ' w';

            % Castling availability?
            kq = obj.kquery();
            kpure = [obj.get(kq(1)).FlagPure, obj.get(kq(2)).FlagPure];

            rep = rep + ' ';

            if any(kpure)
               
                if kpure(1)
                    rep = rep + 'KQ';
                end

                if kpure(2)
                    rep = rep + 'kq';
                end
            else
                rep = rep + '-';
            end


            % En passant square? (we haven't started so defualt to -)
            rep = rep + ' -';

            % Halfmove clock?
            rep = rep + ' 0';

            % Fullmove number?
            rep = rep + ' 1';
        end


        % "Position of piece"
        % Gets the positions of the given piece.
        % There might be more than 1 of that piece (such as white rook) so
        % it will usually be an array.
        %
        % cb.getpos(WhiteRook)
        %
        function pos = getpos(obj, piece)
            pos = obj.pquery(piece.Type, piece.Player);
        end

        %
        % "Query pieces"
        % This function gives you a cell array with all the pieces
        % currently on the board (handy if you need to loop through all the
        % pieces).
        %
        % This includes their position as well.
        %
        % cb.query()
        %           = {{ChessPiece, [3,4]}, {ChessPiece, [2,4]}, {ChessPiece, [1,3]}...}
        %
        function pieces = query(obj)
            indices = find(cellfun(@(p) ~iseabs(p), obj.Board));

            pieces = arrayfun(@(ind) {obj.get(unflat(ind, 8)), unflat(ind, 8)}, indices, 'UniformOutput', false);

            % lame readable approach :c
            % pieces = cell(length(indices));

            % for i = 1:length(indices)
            %     pieces(i) = {obj.Board(indices(i), indices(i))};
            % end
        end

        % "Antiquery"
        %
        % Gets all empty spaces.
        %
        function pieces = aquery(obj)
            indices = find(cellfun(@(p) iseabs(p), obj.Board));

            pieces = arrayfun(@(ind) {obj.get(unflat(ind, 8)), unflat(ind, 8)}, indices, 'UniformOutput', false);
        end

        % "Enigma query"
        %
        % Gets all enigma pieces for that player.
        function pieces = equery(obj, player)
            indices = find(cellfun(@(p) ~iseabs(p) && p.Player == player && ~isempty(p.Enigmas), obj.Board));

            pieces = arrayfun(@(ind) {obj.get(unflat(ind, 8)), unflat(ind, 8)}, indices, 'UniformOutput', false);
        end

        % "Piece query"
        %
        % Gets pieces of player {[piece, pos]...}
        % You can either pass in 1 parameter (ChessPiece)
        %                     or 2 parameters (type, player)
        %
        function pieces = pquery(obj, varargin)
            if nargin == 3
                jp = ChessPiece(varargin{1}, varargin{2});
            else
                jp = varargin{1};
            end

            pbuffer = Buffer(16);

            for i = 1:8
                for j = 1:8
                    cp = obj.get([i,j]);

                    if (~iseabs(cp) && cp == jp)
                        pbuffer.a({cp, [i,j]});
                    end
                end
            end

            pieces = pbuffer.flush();
        end

        % "King query"
        % Queries both kings, only position. 0 if non-existent; [white, black]
        function kings = kquery(obj)
            whitepq = obj.pquery(PieceType.King, 1);
            blackpq = obj.pquery(PieceType.King, 2);

            if isempty(whitepq)
                kings{1} = 0;
            else
                wk = whitepq{1};
                kings{1} = wk{2};
            end

            if isempty(blackpq)
                kings{2} = 0;
            else
                bk = blackpq{1};
                kings{2} = bk{2};
            end
        end

        % "Query's valid pieces"
        % Gets indices of query array that have any valid moves.
        % ...this doesn't mean they will be good moves.
        function inds = qvp(obj, query)
            % Extract position vector
            qpos = exti(query, 2);

            % Get indices
            % inds = find(~isempty(obj.vmoves(qpos)));
            ibuffer = Buffer(length(qpos));

            for i = 1:length(qpos)
                if ~isempty(obj.vmoves(qpos{i}))
                    ibuffer.a(i);
                end
            end

            inds = cell2mat(ibuffer.flush());
        end

        % "Is relative piece @ position that player type?"
        % This is simply ispabs() but only requires a position instead.
        function result = isprel(obj, pos, player)
            result = ispabs(obj.get(pos), player);
        end

        % "Correspondence"
        % Creates the abstract correspondence (sprite index array) for the concrete
        % representation (board cell array) based on OSU Components
        % conventions.
        %
        % Tip: chain this with mow() on Layer 2 for easy updating.
        %
        % The example below uses the pieceExistsMapper function (you can
        % pass functions instead of vars by putting @), which is
        % what it says on the tin — if it exists, then abstract it as 1,
        % otherwise 0. Thus the correspondence reflects that.
        %
        % cb.correspond(@pieceExistsMapper)
        %                   = [1, 1, 1, 1, 1, 1, 1, 1;
        %                      1, 1, 1, 1, 1, 1, 1, 1;
        %                      0, 0, 0, 0, 0, 0, 0, 0;
        %                      0, 0, 0, 0, 0, 0, 0, 0;
        %                      0, 0, 0, 0, 0, 0, 0, 0;
        %                      0, 0, 0, 0, 0, 0, 0, 0;
        %                      1, 1, 1, 1, 1, 1, 1, 1;
        %                      1, 1, 1, 1, 1, 1, 1, 1]
        %
        %
        % The example below uses the intended mapper @repMapper, which
        % converts each ChessPiece (or 0) to its intended sprite index.
        % This also means any sprite indices are hard-coded, so any changes
        % to the spritesheet should be manually reflected in the mapper.
        %
        % This means you can directly slot this onto the Layer 2 matrix via
        % the "matrix overwrite" function or mow()!
        %
        % corr = cb.correspond(@repMapper)
        %                   = [15, 16, 14, 13, 12, 14, 16, 15;
        %                      11, 11, 11, 11, 11, 11, 11, 11;
        %                      100, 100, 100, 100, 100, 100, 100, 100;
        %                      100, 100, 100, 100, 100, 100, 100, 100;
        %                      100, 100, 100, 100, 100, 100, 100, 100;
        %                      100, 100, 100, 100, 100, 100, 100, 100;
        %                      1, 1, 1, 1, 1, 1, 1, 1;
        %                      5, 6, 4, 2, 3, 4, 6, 5]
        %
        % layer2 = mow(layer2, corr, [3,1])
        %
        function abscorr = correspond(obj, mapper)
            abscorr = cellfun(mapper, obj.Board);
        end

        % "Stringify"
        % Gets a string representation with proper line
        % breaks.
        function rep = stringify(obj)
            bsize = size(obj.Board);
            rep = strings(bsize(1), 1);

            for i = 1:bsize(1)
                for j = 1:bsize(2)
                    rep(i) = rep(i) + ' ' + unicodeMapper(obj.get([i,j])) + ' ';
                end
            end
        end

        %
        % "Is unobstructed"
        % This function, given a start (oldPos) and end position (newPos)
        % tells you if there are any pieces between them ("obstructing" the
        % path).
        %
        % REQUIRED: oldPos and newPos are on the board and path is
        % unit-straight.
        %
        % cb.isuno([1,1], [5,5])
        %           = 0 <-- the diagonal path is clear
        %

        function result = isuno(obj, oldPos, newPos)
            if ~isunst(newPos - oldPos)
                error("isuno can only be called on a unit-straight offset!");
            end

            oldPos = unflat(oldPos, 8);
            newPos = unflat(newPos, 8);

            indices = indmat(oldPos, newPos);

            % Remove piece itself
            indices = indices(2:length(indices));

            result = all(cellfun(@(p) obj.iserel(p), indices));
        end

        %
        % "Get piece from position"
        % This function extracts the item at the board position.
        % You can pass it either an flat index or index pair.
        %
        % cb.get(13) <-- 8 + 5, so row 2 item 5
        %           = ChessPiece
        %
        % cb.get([2,5]) <-- same as above
        %           = ChessPiece

        function item = get(obj, pos)
            pos = unflat(unwrap(pos, 1), 8);

            item = obj.Board{pos(1), pos(2)};
        end

        %
        % "Is empty relative"
        % This function tells you if the board position is empty or not.
        %
        % Similar to iseabs(piece), which tells you if the extracted
        % "piece" is 0 or actually a piece.
        %
        % cb.iserel([1,1])
        %           = 1 <-- the space is empty
        %

        function result = iserel(obj, pos)
            piece = obj.get(unflat(pos, 8));

            result = (isa(piece, "double"));
        end

        %
        % "Is opponent"
        % This function tells you if the piece at the board position is an
        % opponent or not.
        %
        % The player parameter is the current player, so either 1 or 2.
        %
        % cb.isoppo([3,3], 1)
        %           = 1 <-- given we are white, the piece at [3,3] is an opponent (black)
        %

        function result = isoppo(obj, pos, player)
            piece = obj.get(unflat(pos, 8));

            result = (~iseabs(piece) && piece.Player ~= player);
        end

        % "Indices until obstacle"
        % This function gives you an array of spaces from your starting
        % position until it either reaches edge of the board or a piece in
        % the way. It doesn't take into account what kind of piece it is,
        % just that it can move in that direction (same output whether pawn or
        % bishop, for example).
        %
        % The dir parameter is in the form Direction.[something], so
        % Direction.Left, Direction.Right, etc. This is which way you are
        % checking. Open the "Direction.m" file to see all options. The
        % directions are all relative (it takes into account which way each
        % player is facing) so down doesn't necessarily mean always going
        % down rows of the matrix.
        %
        % The oppoAware parameter stands for "is aware of opponents", and
        % instead of stopping before any piece will include that occupied
        % space if it has an opponent piece (useful for capturing pieces).
        % Set it to 0 to disable, 1 for enable and current player is white,
        % 2 for enable and current player is black.
        %
        % ~~Note what is returned are flat indices, so instead of [row,
        % column] it is the # of spaces from the top-left corner. You can
        % still index an array with it. array(10) is the same as
        % array([1,2])!~~
        %
        % 2D indices are returned now!
        %
        % cb.iuntil([2,2], Direction.LeftUp, 0)
        %           = [18, 25, 33] <-- the pawn at [2,2] can go diagonally
        %                              left and up for these 3 spaces until
        %                              reaching the board edge or an
        %                              obstacle
        %
        % cb.iuntil([4,4], Direction.Down, 2)
        %           = [8, 16, 24, 32] <-- the black rook at [4,4] can go
        %                                 downwards for these four spaces
        %                                 until reaching board edge or
        %                                 obstacle (obstacle is a white
        %                                 bishop so it is included in
        %                                 possible moves)
        %

        function indices = iuntil(obj, pos, dir, oppoAware)
            indices = obj.iuntilmax(pos, dir, 8, oppoAware);
        end

        % "Indices until obstacle or max spaces"
        % This function is the same as iuntil() but you can give it a max #
        % of spaces it can move too — for the king you would use max = 1.
        %
        % cb.iuntil([1,5], Direction.Up, 0)
        %                   = [13, 21, 29] <-- the black king has three
        %                                      open spaces in front of it
        %
        % cb.iuntilmax([1,5], Direction.Up, 1, 0)
        %                   = [13]         <-- the black king can only move
        %                                      1 space, so limit to max of
        %                                      1.
        %
        function indices = iuntilmax(obj, pos, dir, max, oppoAware)
            % Unflat pos
            pos = unflat(pos, 8);

            % Get offset from direction, and relative fix based on player
            offset = dir.Offset;
            if (obj.get(pos).Player == 1)
                offset = -offset;
            end

            % Last valid position until obstruction/off-board
            lastValidPos = pos;

            % # of spaces checked.
            numSpaces = 0;

            % Run condition.
            isFinding = 1;

            % Keep searching in direction until BEFORE invalid index hit or
            % checked spaces = max.
            while (isFinding)
                % Look-ahead at next hit.
                nextPos = lastValidPos + offset;
                isFinding = valabs(nextPos) && obj.iserel(nextPos) && numSpaces + 1 <= max;

                % Apply (confirmed) offset; if oppo aware and is opposing player then add and
                % stop.
                if (isFinding || (numSpaces + 1 <= max && valabs(nextPos) && oppoAware && obj.isoppo(nextPos, oppoAware)))
                    lastValidPos = nextPos;
                    numSpaces = numSpaces + 1;
                end
            end

            % Add all indices
            indices = indmat(pos, lastValidPos);

            % Remove current position (1st item).
            indices = indices(2:length(indices));
        end

        % "Get consuming moves for player"
        % Gets all consuming moves for particular player.
        % Stored as pair of coords (old and new) since this targets all
        % rather than just 1 piece.
        function movepairs = cpmoves(obj, player)
            types = [ PieceType.Pawn, PieceType.Knight, PieceType.King, PieceType.Bishop, PieceType.Queen, PieceType.Rook ];
            mpbuffer = Buffer(20);

            % For every piece type...
            for type = types
                % Get all positions for pieces of that type...
                typepos = exti(obj.pquery(type, player), 2);

                % For every position get every cmoves...
                for tpcell = typepos
                    tp = unwrap(tpcell, 1);
                    cmoves = obj.cmoves(tp);

                    % For every cmoves, add to movepairs.
                    if ~isempty(cmoves)
                        for ccell = cmoves
                            c = ccell{1};
                            mpbuffer.a({tp, c});
                        end
                    end
                end
            end

            movepairs = mpbuffer.flush();
        end

        % "Get checking moves"
        % This includes enigma moves!!
        function moves = chmoves(obj, pos) 
            % Get position's player
            player = obj.get(pos).Player;
            
            % Get position's opponent
            oplayer = circ(player + 1, 1, 2);

            % Get all valid moves for piece
            moves = [ obj.vmoves(pos), obj.evmoves(pos) ];

            % Keep only the moves that put other opponent in check
            for i = length(moves):-1:1
                % Get move
                move = moves{i};
                
                % Check if that move puts opponent in check
                if obj.isresmove(pos, move, oplayer)
                    moves(i) = [];
                end
            end
        end

        % "Get checking moves for player"
        % Gets all moves that check the other player for particular player.
        % See instructions for cpmoves.
        function movepairs = chpmoves(obj, player)
            types = [ PieceType.Pawn, PieceType.Knight, PieceType.King, PieceType.Bishop, PieceType.Queen, PieceType.Rook ];
            mpbuffer = Buffer(50);

            % For every piece type...
            for type = types
                % Get all positions for pieces of that type...
                typepos = exti(obj.pquery(type, player), 2);

                % For every position get every chmoves...
                for tpcell = typepos
                    tp = tpcell{1};
                    cmoves = obj.chmoves(tp);

                    % For every cmoves, add to movepairs.
                    if ~isempty(cmoves)
                        for ccell = cmoves
                            c = ccell{1};
                            mpbuffer.a({tp, c});
                        end
                    end
                end
            end

            movepairs = mpbuffer.flush();
        end


        % "Get consuming moves for piece"
        % Gets indices of vmoves that are moves that consume a piece.
        % Handy for check checking or ChessBot move priority.
        function moves = cmoves(obj, pos)
            mbuffer = Buffer(5);

            piece = obj.get(pos);

            % Check if not empty.
            if ~iseabs(piece)
                player = piece.Player;
                
                allmoves = [ obj.vmoves(pos, -1), obj.evmoves(pos) ];

                for i = 1:length(allmoves)
                    move = unwrap(allmoves{i});

                    if obj.isoppo(move, player)
                        mbuffer.a(move);
                    end
                end
            end

            moves = mbuffer.flush();
        end

        % "Get valid moves for player"
        % Gets all valid moves for a player in a cell array in {{oldpos,
        % newpos}...} format. Uniquely accepts prio parameter due to use in
        % checkmate.
        function movepairs = vpmoves(obj, player, prio)
            if nargin < 3
                prio = 1;
            end

            types = [ PieceType.Pawn, PieceType.Knight, PieceType.Bishop, PieceType.Rook, PieceType.Queen, PieceType.King ];
            mpbuffer = Buffer(50);

            % For every piece type...
            for type = types
                % Get all positions for pieces of that type...
                typepos = exti(obj.pquery(type, player), 2);

                % For every position get every vmoves...
                for tpcell = typepos
                    tp = tpcell{1};
                    vmoves = obj.vmoves(tp, prio);

                    % For every cmoves, add to movepairs.
                    if ~isempty(vmoves)
                        for vcell = vmoves
                            v = vcell{1};
                            mpbuffer.a({tp, v});
                        end
                    end
                end
            end

            movepairs = mpbuffer.flush();
        end

        % "Filter resolving moves for piece"
        % Get subset of moves from a given set of moves from a static position (such as vmoves)
        % that are resolving (or don't put the player in check).
        function submoves = frmoves(obj, pos, moves)
            % Get the player!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            player = obj.get(pos).Player;

            % Loop through all the moves.
            submoves = moves;

            for i = length(submoves):-1:1
                % Remove if not resolving (puts in check).
                if ~obj.isresmove(pos, submoves{i}, player)
                    submoves(i) = [];
                end
            end
        end

        % "Filter resolving moves for player"
        % Get subset of moves from a given set of  (use player moves
        % functions such as vpmoves or cpmoves)
        % that are resolving (see frmoves for details)
        function submovepairs = frpmoves(obj, movepairs, player)
            % Loop through all the movepairs.
            submovepairs = movepairs;

            for i = length(submovepairs):-1:1
                % Get the start and end of movepair
                submovepair = submovepairs{i};
                submstart = submovepair{1};
                submend = submovepair{2};

                % Remove if not resolving (puts in check)
                if ~obj.isresmove(submstart, submend, player)
                    submovepairs(i) = [];
                end
            end
        end

        % "Get resolving moves for piece"
        % Integrates checkresmove to ensure the moves passed in resolve check.
        % You should only pass either vmoves and/or emoves into this!
        function submoves = rmoves(obj, pos)
            % If empty, return.
            if obj.iserel(pos)
                submoves = [];
            else
                % Get all valid moves
                submoves = obj.vmoves(pos, 1);

                % Get player of piece @ position
                player = obj.get(pos).Player;


                % Remove any moves that won't resolve check
                for i = length(submoves):-1:1
                    rm = unwrap(submoves{i});

                    if ~obj.isresmove(pos, rm, player)
                        submoves(i) = [];
                    end
                end
            end
        end

        % "Get resolving enigma moves for piece"
        % Same as rmoves. Please don't confuse this with removing a piece.
        function submoves = removes(obj, pos)
            % If empty, return.
            if obj.iserel(pos)
                submoves = [];
            else
                % Get all valid moves
                submoves = obj.evmoves(pos);

                % Get player of piece @ position
                player = obj.get(pos).Player;


                % Remove any moves that won't resolve check
                for i = length(submoves):-1:1
                    rm = submoves{i};

                    if ~obj.isresmove(pos, rm, player)
                        submoves(i) = [];
                    end
                end
            end
        end

        % "Get resolving moves for player"
        % Does enigmas as well! :D
        function movepairs = rpmoves(obj, player)
            types = [ PieceType.Pawn, PieceType.Knight, PieceType.Bishop, PieceType.Rook, PieceType.Queen, PieceType.King ];
            
            mpbuffer = Buffer(40);

            % For every piece type...
            for type = types
                % Get all positions for pieces of that type...
                typepos = exti(obj.pquery(type, player), 2);

                % For every position get all rmoves
                for tpcell = typepos
                    tp = unwrap(tpcell, 1);

                    rmoves = obj.rmoves(tp);

                    % For every rmoves, add to movepairs.
                    if ~isempty(rmoves)
                        for rcell = rmoves
                            mpbuffer.a({tp, unwrap(rcell, 1)});
                        end
                    end
                end
            end

            % For all enigma pieces of player...
            for epcell = exti(obj.equery(player), 2)
                ep = unwrap(epcell, 1);
                % Get all evmoves
                evmoves = obj.evmoves(ep);

                % For every evmoves, add to movepairs.
                    for ecell = evmoves
                        mpbuffer.a({ep, unwrap(ecell, 1)});
                    end
            end

            movepairs = mpbuffer.flush();
        end

        %
        % "Get valid moves for piece"
        % This function returns a cell array of all the valid moves for a
        % piece at the given position.
        %
        % Note that "moves" represents absolute indices (rather than
        % relative to the given position), so you can directly use these to
        % change the sprites on the board where the user can move the
        % piece.
        %
        % UPDATE: This also takes into account checking!!
        %
        % To iterate through a cell array, you can use foreach loop and extract
        % each from cells like so:
        %
        % for cell in moves
        %   index = cell{1};
        %   ...
        % end
        %
        % ...or, you can use a regular forloop and use the extract
        % function.
        %
        % for i = 1:length(moves)
        %   index = moves{i};
        %   ...
        % end
        %
        %
        % cb.vmoves([7,6])
        %           = { }                    <-- there are no possible moves for this pawn
        %
        % cb.vmoves([1,8])
        %           = { [2,8], [2,9] }       <-- the pawn can go diagonally to
        %                                        the left or forward 1.
        %
        % cb.vmoves([5,7])
        %           = { 13, 15, 16, 19, 54 } <-- the bishop is implemented
        %                                        using iuntil() and gives
        %                                        absolute indices. You can
        %                                        still loop through and use
        %                                        them!
        %
        % The NEW prio (performance) parameter determines which aspects to
        % skip (this is primarily regarding speeding up the AI; imperative
        % player moves should be left at prio 1).
        %
        % -1 -> Skips castling/en passant (same as 2), INCLUDES diagonal moves for
        % pawns.
        % 1 -> Calculates all (castling and en passant).
        % 2 -> Skips castling and en passant. Default.
        % 3 -> Skips pawns, castling, and en passant.

        function moves = vmoves(obj, pos, prio)
            isforcedp = false;

            % Set prio if not passed.
            if nargin < 3
                prio = 2;
            elseif prio == -1
                isforcedp = true;
                prio = 2;
            end

            % Get chess piece object
            piece = obj.get(unflat(pos, 8));

            % This is a buffer — this is more efficient than the original
            % Queue which had to resize every time which was very costly.
            % Increasing priority takes a larger initial cost to avoid
            % resizing as much as possible; normally we risk a lil.
            bfr = Buffer(clamp(10 * prio, 15, 30));

            % If no piece present, skip all checks.
            if ~iseabs(piece)
                player = piece.Player; % 1 for white, 2 for black

                % Check all potential moves based on piece type.
                switch (piece.Type)
                    case PieceType.Pawn
                        if prio < 3
                            % Move forward 1 space (## target is empty)
                            move_fw1 = rel2abs(pos, [1,0], player);

                            if (valabs(move_fw1) && obj.iserel(move_fw1))
                                bfr.a(move_fw1);
                            end

                            % Move forward 2 spaces (## pure-flagged, target is empty and path unobstructed)
                            if piece.FlagPure
                                move_fw2 = rel2abs(pos, [2,0], player);

                                if (valabs(move_fw2) && obj.isuno(pos, move_fw2))
                                    bfr.a(move_fw2);
                                end
                            end

                            % Diagornal 1 space (## target occupied by opponent)
                            % + en passant (## pawn on 1 row into opponent, prior
                            % turn opponent pawn 2-hopped to horizontal adjacent)

                            moves_diag = { [1,1], [1,-1] };

                            % Filter invalid moves (normally this would be
                            % implicitly done via valabs check, but we need to
                            % always check diagonals for en passant now.
                            moves_diag = moves_diag(cellfun(@(m) valrel(pos, m, player), moves_diag));

                            if isforcedp
                                bfr.aa(cellfun(@(m) rel2abs(pos, m, player), moves_diag, "UniformOutput", false));
                            else
                                for i = 1:length(moves_diag)
                                    relmove = moves_diag{i};

                                    if prio < 2
                                        % Absolute conversion
                                        absmove = rel2abs(pos, relmove, player);


                                        % En passant row for your piece
                                        enp_row = 3 + player;

                                        % En passant's other piece.
                                        enp_oppo = obj.get(rel2abs(pos, [0, relmove(2)], player));

                                        % Verbose/one-liner for compactness. Checks if
                                        % move itself is valid, then if either opponent
                                        % or [EN PASSANT CONDITIONS] add.

                                        % Note that ensuring enp_row guarantees
                                        % enp_oppo is valid (skipping a valrel) but we
                                        % do still need to check emptiness hence var
                                        % separation.

                                        % o/ hiya--! you actually don't need to check if
                                        % there is a piece to capture or not... since a
                                        % 2-hop requires empty space!

                                        if valabs(absmove) && (obj.isoppo(absmove, player) || (prio == 1 && pos(1) == enp_row && ~iseabs(enp_oppo) && enp_oppo.Type == PieceType.Pawn && enp_oppo.FlagTemp))
                                            bfr.a(absmove);
                                        end
                                    end
                                end
                            end
                        end

                    case PieceType.King
                        % All spaces in 1-space radius (## target
                        % unoccupied or is opponent)
                        for dir = Direction.dirs
                            bfr.aa(obj.iuntilmax(pos, dir, 1, player));
                        end

                        % Castling (## king & rook pure-flagged,
                        % unobstructed, not in check on each consec space)

                        % Note that castling only works for the default
                        % chess layout (or at least if rooks/king are in
                        % same spots).

                        % If king is not purity-flagged, skip all. This
                        % doesn't mean we can apply the king's position.
                        if prio < 2 && piece.FlagPure
                            moves_castle = { [0,-2], [0,2] };

                            for i = 1:length(moves_castle)
                                relmove = moves_castle{i};

                                % Absolute conversion
                                absmove = rel2abs(pos, relmove, player);

                                % Opposite player. We use this for iuntil
                                % since we actually want to include
                                % same-player rook!
                                oppoplayer = circ(player + 1, 1, 2);

                                % Ensure unobstructed and conveniently grab
                                % rook positions easily (edges of board).
                                edgepath = obj.iuntil(pos, Direction.normalise(relmove), oppoplayer);

                                % Since testing checks is costly, apply
                                % any possible checks prior. No board-edge
                                % check to allow castling in more layouts.

                                % (a) path ≥ 1, (a) end of path is rook, (b) rook is
                                % pure-flagged
                                if length(edgepath) >= 1 && ~obj.iserel(edgepath{end})
                                    rpospiece = obj.get(edgepath{end});

                                    if rpospiece == ChessPiece(PieceType.Rook, player) && rpospiece.FlagPure
                                        % (c) Add if king not checked on all
                                        % spots.
                                        if all(cellfun(@(p) obj.isresmove(pos, p, player), edgepath))
                                            bfr.a(absmove);
                                        end
                                    end
                                end
                            end
                        end

                    case PieceType.Rook
                        % All spaces on horizontal/vertical until
                        % obstructed
                        for dir = Direction.dirs(1:4)
                            bfr.aa(obj.iuntil(pos, dir, player));
                        end

                    case PieceType.Bishop
                        % All spaces on diagonals until obstructed
                        for dir = Direction.dirs(5:8)
                            bfr.aa(obj.iuntil(pos, dir, player));
                        end

                    case PieceType.Queen
                        % All spaces on hor/vert/diagonals until obstructed
                        for dir = Direction.dirs
                            bfr.aa(obj.iuntil(pos, dir, player));
                        end

                    case PieceType.Knight
                        % This is the 8 potential indices in relative form.
                        relMoves = { [1,-2], [1,2], [2,-1], [2,1], [-2,-1], [-2,1], [-1,-2], [-1,2] };

                        % Filter out off-board moves
                        relMoves = relMoves(cellfun(@(p) valrel(pos,p,player), relMoves));

                        % Convert to absolute indices
                        absMoves = cellfun(@(p) rel2abs(pos,p,player), relMoves, 'UniformOutput', false);

                        % Add if unoccupied or is opponent
                        for move = absMoves
                            emove = unwrap(move, 1);
                            if (obj.iserel(emove) || obj.isoppo(emove, player))
                                bfr.a(emove);
                            end
                        end
                end
            end

            % Convert queue to vector.
            moves = bfr.flush();
        end

        % "Enigma valid moves"
        % Separated for ease of coloring.
        function moves = evmoves(obj, pos)
            piece = obj.get(pos);
            player = piece.Player;

            if ~iseabs(piece)
                enigmas = vdecomp(piece.Enigmas);
                bfr = Buffer(20);

                for i = 1:length(enigmas)
                    e = enigmas{i};
                    etype = e{1};
                    ecount = e{2};

                    % Note: you can be guaranteed at least 1 of the type
                    % exists, hence a few assumptions below (see Sidewind)
                    switch etype
                        case EnigmaType.Backtrot % ## unoccupied [-1]
                            move_bt = rel2abs(pos, [-1,0], player);

                            if valabs(move_bt) && obj.iserel(move_bt)
                                bfr.a(move_bt);
                            end
                        case EnigmaType.Sidewind % ## unoccupied [2]
                            % All possible moves
                            potens = {[0,-1], [0,1]};

                            % Get corresponding amount of moves based on
                            % ecount
                            potens = potens(1:ecount);

                            for p = potens
                                move = rel2abs(pos, p{1}, player);

                                if valabs(move) && obj.iserel(move)
                                    bfr.a(move);
                                end
                            end
                        case EnigmaType.Protractor % ## unoccupied or opponent [4]
                            potens = { [2,-2], [-2,2], [2,2], [-2,-2] };
                            potens = potens(1:ecount);

                            for p = potens
                                move = rel2abs(pos, p{1}, player);

                                if valabs(move) && (obj.iserel(move) || obj.isoppo(move, player))
                                    bfr.a(move);
                                end
                            end
                        case EnigmaType.Missile % ## has opponent in n radius [3]
                            radius = ecount; % 1x1, 2x2, 3x3
                            rspaces = frring(radius, pos);

                            for rscell = rspaces
                                rs = rscell{1};

                                if obj.isoppo(rs, player)
                                    bfr.a(rs);
                                end
                            end
                        case EnigmaType.Panick % ## is checked, unoccupied or opponent  [3]
                            potens = { [0,2], [0,-2], [2,0], [-2,0], [2,2], [2,-2], [-2,2], [-2,-2] };
                            potens = potens(1:ecount);

                            ischecked = obj.Checks(player);

                            for p = potens
                                move = rel2abs(pos, p{1}, player);

                                % More efficient to only query once and
                                % check if same player.
                                if ischecked && valabs(move) && isplayer(obj.get(move), player)
                                    bfr.a(move);
                                end
                            end
                        case EnigmaType.Magnesis % ## nothing to do [3]
                        case EnigmaType.Chakra % ## nothing to do [1]
                    end
                end

                moves = bfr.flush();
            else
                moves = [];
            end
        end

        % "Board score"
        % For the purposes of making the AI pick prioritising moves, use
        % this to get a quantitative comparator for the current (or
        % look-ahead) board. Score should not be based on lookaheads.
        % Positive favours white, vice versa for black. Location-agnostic.

        % Note shown score adds are relative to each player (+ for black should
        % be -).

        % This is handy for an alternative gamemode (e.g. based on reaching
        % particular score) or for bot in determining spread of move
        % priority
        % (higher score disparity = tighter chance spread = higher chance of #1 move).
        function score = bscore(obj)
            % +10 (+5/r) for each piece (+ for each rank)
            % +5/e for total enigmas
            score = 0;

            % Location-agnostic so strip locs.
            pieces = exti(obj.query(), 1);
            
            for i = 1:length(pieces)
                piece = unwrap(pieces(i), 1);
                score = score + circ(piece.Player, -1, 1) * 10 + 5 * piece.rank() + 5 * length(piece.Enigmas());
            end
        end

        % "Move score"
        % Gets the added score for the given move. Don't compound this with
        % board score. See bscore() for more details. Preferably, retain priority brackets unless it is particularly
        % egregious (puts self in check, loses queen, etc). This is a
        % VERY COSTLY(!!!!) operation.
        %
        % This score is RELATIVE to the player!
        function score = mscore(obj, oldPos, newPos, enigspace)
            score = 0;
            
            board = obj.cpy();

            mpiece = board.get(oldPos);           
            mplayer = mpiece.Player;
            oplayer = circ(mplayer+1, 1, 2);
            mcap = board.pmove(oldPos, newPos);
            
            % +999 for checkmates opponent, +15 for checks opponent
            if board.Checks(mplayer) == 2
                score = score + 999;
            elseif board.Checks(mplayer) == 1
                score = score + 15;
            end

            % +50 for castling
            if iscastle(oldPos, newPos, mpiece)
                score = score + 50;
            end
            
            % +20 (+5/r) for consumes piece (+ for captured's rank), +5/e for
            % each of consumed's enigma
            if ~iseabs(mcap)
                score = score + 20 + 5 * abs(mcap.rank()) + 5 * length(mpiece.Enigmas);
            % +25 (-2/e) for gets enigma (- for total enigmas, minimum 10)
            elseif psame(newPos, enigspace)
                score = score + max(25 - 2 * sum(cellfun(@(p) length(p.Enigmas), exti(board.equery(mplayer), 1))), 10);
            end
                
            % +3/m for each additional potential consume (after moving),
            % clamped to 5
            score = score + clamp(3 * length(board.cmoves(newPos)), 0, 5);

            % -40 (-3/r, -2/o) if piece can be consumed next turn (- for your rank? rank disparity? & for # of opponents taking u)
            oppocmoves = board.cpmoves(oplayer);

            if has(exti(oppocmoves, 2), newPos)
                score = score - 40 - 3 * abs(mpiece.rank()) - 2 * length(avfilt(exti(oppocmoves, 2), newPos));
            end

            % -5 (-2/r) for any other pieces that can be consumed
            % currently (to encourage AI to protect pieces)
            for conpcell = puniq(exti(oppocmoves, 2))
                conpiece = board.get(conpcell);
                score = score - 5 - 2 * abs(conpiece.rank());
            end


             % +10/p for each piece protecting this piece (due to this
             % obscure use-case, it doesn't warrant another +50 lines to
             % this abhorrently long file...!)

             % This uses a clever trick due to being the last operation on
             % this "temp board"; by swapping player of moved piece you can
             % check if any cmoves of YOU can "capture" that piece.
             mpiece.Player = oplayer;

             score = score + 10 * length(avfilt(exti(board.cpmoves(mplayer), 2), newPos));
            
             fprintf("[%i, %i] ➡ [%i, %i] = %ipts\n", oldPos, newPos, score);
             
             % Clear board memory
             clear board;
        end

        % "PGN + pmove"
        % Does the pmove and adds to PGN. Pass in parameter "nag" to
        % manually set NAG (and skip costly check), otherwise automatically
        % calculates NAG.
        %
        % Returns capture for chaining.
        %
        function capture = pgnmove(obj, oldpos, newpos, pgn, comm, nag)
            if nargin < 5
                comm = '';
            end

            if nargin < 6
                nag = PGN.move2nag(obj, oldpos, newpos, 0);
            end

            capture = obj.pmove(oldpos, newpos);
            pgn.amt(oldpos, newpos, capture, comm, nag);
        end

        % "Move piece"
        % Moves the piece at old position to new position.
        % If there was a piece there, it is replaced (the removed piece
        % is set to the variable "capture"). Updates flags and also handles
        % multi-piece operations (e.g. castling, en passant)
        %
        % @requires oldPos to have a piece, newPos to not have same colored
        % piece
        %
        % cb.pmove([1,1], [3,3])
        %           = 0           <-- moved piece from [1,1] to [3,3]. No
        %                             piece was there so capture = 0.
        %
        % cb.pmove([1,2], [3,3])
        %           = ChessPiece  <-- moved white knight from [1,2] to [3,3].
        %                             There was a black rook so it is
        %                             replaced and set to "capture"
        %                             variable.
        %
        function capture = pmove(obj, oldpos, newpos)

            offset = oldpos - newpos;

            % Enforce precondition A
            if obj.iserel(oldpos)
                error("Cannot pmove with empty space!");
            end

            if ~psame(oldpos, newpos)
                piece = obj.get(oldpos);
                player = piece.Player;
                capture = obj.get(newpos);

                % Enforce precondition B
                if ~iseabs(capture) && player == capture.Player
                    error("Cannot pmove to space with piece of same player!");
                end

                % If king castle (king moved L/R more than 1 space w/out
                % Panick), move rook as well.

                % Note that being unable to castle with Panick is a BUG,
                % but perhaps its just balancing!!! wooooo!!!!!
                
                % Usually checking for X spaces moved is irksome due to
                % diagonals adding up in distance to over X, but since we
                % can guarantee L/R 'tis simple! In fact,
                % Direction.normalise() or isunst() isn't even needed due to guaranteed
                % oldPos ≠ newPos for a fun clean solution.
                if piece.Type == PieceType.King && ~has(piece.Enigmas, EnigmaType.Panick) && offset(1) == 0 && abs(offset(2)) == 2
                    % We've already guaranteed direction is L/R, we can
                    % safely normalise now. 
                    if player == 1
                        cdir = Direction.normalise(offset);
                    else
                        cdir = Direction.normalise(-offset);
                    end

                    % By proxy of being castling move, we can guarantee
                    % rook is present and unobstructed. Thus we can nab
                    % piece at last index of iuntil safely. also that name
                    % is criminal smh my head -.<
                    
                    % Also note the neat circ() trick for flipping player —
                    % this is so we stop right at the same-player rook!
                    cpath = obj.iuntil(oldpos, cdir, circ(player+1, 1, 2));
                    crook = cpath(end);
    
                    % Move the rook right next to the king! Note how we can
                    % safely flip direction without fear as we guaranteed
                    % it L/R.
                    obj.pmove(unwrap(crook, 1), rel2abs(newpos, -cdir.Offset, player));

                    % disp("CASTLE");
                end

                obj.Board{newpos(1), newpos(2)} = piece;
                obj.Board{oldpos(1), oldpos(2)} = 0;
              
                % Nullify purity
                piece.FlagPure = 0;

                % If pawn 2-hop, temp-flag.
                if piece.Type == PieceType.Pawn && psame(rel2abs(oldpos, [2,0], player), newpos)
                    piece.FlagTemp = 1;
                end

                % If pawn en passant (diagonal & no capture), remove passed pawn.
                if piece.Type == PieceType.Pawn && iseabs(capture) && (psame(rel2abs(oldpos, [1,1], player), newpos) || psame(rel2abs(oldpos, [1,-1], player), newpos))
                    % Since pawn has already moved to newPos, just remove the
                    % piece directly down from it.
                    obj.Board{newpos(1) - 1, newpos(2)} = 0;
                    
                    disp("EN PASSANT");
                end

                % Update check status
                obj.checkcheck();
            end
        end


        % "Swap pieces"
        % Swaps the pieces at position A and B.
        %
        % REQUIRES posA and posB to have pieces on them
        %
        % cb.pswap([1,1], [8,8]) <-- the white rook and black rook
        %                            swap places on the board
        %
        function pswap(obj, posA, posB)
            if ~psame(oldPos, newPos)
                pieceA = obj.get(posA);
                pieceB = obj.get(posB);

                obj.Board{posA(1), posA(2)} = pieceB;
                obj.Board{posB(1), posB(2)} = pieceA;
                
                pieceA.FlagPure = 0;
                pieceB.FlagPure = 0;
                obj.checkcheck();
            end
        end

        % "Remove piece"
        % Removes the piece at the position.
        % The piece removed is set to "piece" variable.
        %
        % cb.prem([5,5])
        %           = 0            <-- there was no piece to remove at [5,5]
        %
        % cb.prem([3,3])
        %           = ChessPiece   <-- a white rook at [3,3] was removed
        %
        function piece = prem(obj, pos)
            piece = obj.get(pos);

            obj.Board{pos(1), pos(2)} = 0;

            obj.checkcheck();
        end

        % "Overwrite piece"
        % Overwrites the piece at the location (can be empty or have
        % a piece there).
        % The "piece" variable is a ChessPiece (see top of file for how to
        % make a ChessPiece)
        %
        % If there was a piece replaced, then it is set to "ow" variable.
        %
        % cb.pow([2,2], ChessPiece(PieceType.Pawn, 1))
        %           = 0              <-- a white pawn is placed at [2,2]. There
        %                          was nothing there so ow = 0.
        %
        % cb.pow([2,4], ChessPiece(PieceType.Rook, 2))
        %           = ChessPiece      <-- a black rook is placed at [2,4].
        %                                 There was a white queen so it was
        %                                 set to "ow" variable.
        %
        function ow = pow(obj, pos, piece)
            ow = obj.get(pos);

            obj.Board{pos(1), pos(2)} = piece;
            
            % Overwrite should be used while retaining piece state (such as
            % pawn promotion); thus preserve purity flag.
            if ~iseabs(ow)
                piece.FlagPure = ow.FlagPure;
            end
            obj.checkcheck();
        end

        % "Check check"
        % This is an internal checker to update the Board's check status.
        % To access check status you should use obj.Checks.
        % This checks for both checkmate and check so ischeckmate is
        % (mostly) internal now.
        %
        % This code is a highly optimised combo of the decoupled "cmoves", "ischeck",
        % and "ischeckmate" due to high # of calls to checkcheck which is
        % inherently slow.
        function checkcheck(obj)
            for player = 1:2
                checkmate = 0;
                check = 0;
                kq = obj.kquery();
                %cq = obj.cpmoves(player);

                for r = 1:8
                    for c = 1:8
                        % If the space at [r,c] isn't empty and we haven't
                        % confirmed check yet, keep looking for check.
                        if ~check && ~obj.iserel([r,c])

                            % Get all the moves of the piece at [r,c] that
                            % consumes a piece.
                            cmoves = obj.cmoves([r,c]);

                            % Loop through all the cmoves.
                            for j = 1:length(cmoves)
                                cmove = cmoves{j};
                                %If any move in (cmoves) matches the king's position, it means
                                % that the king is in check. We check by ensuring
                                % both are permutations of each other.
                                if psame(cmove, kq{player})
                                    check = true;
                                end
                            end
                        end
                    end
                end

                % Update checkstate (since ischeckmate() relies on check
                % being flagged).
                obj.Checks(player) = check;

                if check && ~checkmate % Checkmate only if checked!
                    % If other player has no rmoves, then
                    % checkmate.

                    % Once we have checked once we can safely
                    % return — doesn't matter how many other ways
                    % we are checked.
                    checkmate = ischeckmate(obj, player);

                    obj.Checks(player) = 1 + checkmate;
                end

                % For a clever branch-save a binary representation of
                % both booleans for 1 or 2 output (whilst avoiding the
                % accursed 'not check but checkmate = 1' scenario). You can
                % do this by representing it as a binary number (e.g. [11]
                % = 0b11) which separates the "0 and 1" case! Hence
                % bin2dec(mat2dig([1,1])) would report 3 and vice versa.
                % For the 01/10 case it would be 1 or 2. We only want
                % 00/10/11 or 0/2/3

                % UPDATE: actually this is not necessary; checkmate is only
                % flagged if check is true — so no need! This remains for
                % documentation.
                
            end
        end

        %this function is going to tell if a move made by a certain player resolves
        %check or not
        %or not
        function result = isresmove(obj, oldPos, newPos, player)
            backup = obj.Board;
            
            % Preserve checkstate (faster than calling checkcheck later)
            checkstate = obj.Checks;

            % Manually move piece without using pmove to avoid recursion.
            % This is simply the pmove code sans checkcheck and purity
            % flag.
            if ~psame(oldPos, newPos)
                piece = obj.get(oldPos);

                obj.Board{newPos(1), newPos(2)} = piece;
                obj.Board{oldPos(1), oldPos(2)} = 0;
            end

            % Get check status
            result = ~ischeck(obj, player);

            %this line restores the chessboard to its previous state
            %this makes sure the move made doesn't change the chessboard
            % permanently, because we were just checking the move before moving
            obj.Board = backup;

            % Restore checkstate
            obj.Checks = checkstate;
        end
    end
end