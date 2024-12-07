clearvars -global
clearvars variables
clear

global pgn BL TL WhitePawn BlackPawn BlackKnight BlackRook BlackBishop BlackQueen isdebug isforfeit isclear coord_clear coord_forfeit coord_debug sfx_blip sfx_sup sfx_err sfx_bloc;

% ****** MODIFY BOARDPRESET HERE *******
cb = ChessBoard(BoardPreset.Standard);
% **************************************

bot = ChessBot(cb, 0.1);

pgn = PGN(cb);
pgn.apopu();

%Sets up simple game engine
chess_game=betterGameEngine('chess_board_and_pieces.png',16,16,4,[245,245,245], 0);

sfx_move = chess_game.cachesound("audio/scrolle.wav");
sfx_movehor = chess_game.cachesound("audio/cur_hor.wav");
sfx_movever = chess_game.cachesound("audio/cur_ver.wav");
sfx_sel = chess_game.cachesound("audio/selected.wav");
sfx_sup = chess_game.cachesound("audio/dollop.wav");
sfx_sdown = chess_game.cachesound("audio/cancel.wav");
sfx_scan = chess_game.cachesound("audio/stomp.wav");
sfx_done = chess_game.cachesound("audio/new_evidence.wav");
sfx_err = chess_game.cachesound("audio/card.wav");
sfx_bloc = chess_game.cachesound("audio/bloc.wav");
sfx_gameover = chess_game.cachesound("audio/gameover.wav");
sfx_win = chess_game.cachesound("audio/clear.wav");
sfx_cap = chess_game.cachesound("audio/diceroll.mp3");
sfx_enighit = chess_game.cachesound("audio/feather.wav");
sfx_enigadd = chess_game.cachesound("audio/1up.wav");
sfx_enigapp = chess_game.cachesound("audio/coin.wav");
sfx_chup = chess_game.cachesound("audio/switch_act.wav");
sfx_chd = chess_game.cachesound("audio/switch_end.wav");
sfx_bomp = chess_game.cachesound("audio/bomp.wav");
sfx_debug = chess_game.cachesound("audio/present.wav");
sfx_blip = chess_game.cachesound("audio/m3_blip.flac");

%Creates bottom layer of scene using individual sprites from image pack
%(chess_board_and_pieces.png file)

BL =[2,1,2,1,2,1,2,1,27;
     1,2,1,2,1,2,1,2,27;
     2,1,2,1,2,1,2,1,27;
     1,2,1,2,1,2,1,2,27;
     2,1,2,1,2,1,2,1,27;
     1,2,1,2,1,2,1,2,27;
     2,1,2,1,2,1,2,1,27;
     1,2,1,2,1,2,1,2,27];
 
% Board border layer
BBL = [44, 31, 31, 31, 31, 31, 31, 41, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       34, 99, 99, 99, 99, 99, 99, 32, 99;
       43, 33, 33, 33, 33, 33, 33, 42, 99];

%Creates top layer of scene using individual sprites from image pack
%(chess_board_and_pieces.png file)
TL=[cb.correspond(@SpriteMapper), [99; 99; 47; 48; 40; 99; 99; 99]];

% Super layer
SL = 99 * ones(8, 9);

%Creates first scene with bottom layer and top layer
drawScene(chess_game,BL,BBL,TL)

%Creates title of the game and desciption of what the game is about
title("CHESS²","FontSize",50, "FontName", "Albuquerque Trial");

%Sets pturn (player turn) variable to 1 to loop the game code for each turn
%of the game
pturn=1;


isdebug = 0;
isforfeit = 0;
isclear = 0;
coord_clear = [3,9];
coord_forfeit = [4,9];
coord_debug = [5,9];

% TEMPORARY
function resetLayers(cb)
global BL TL;
%Resets the bottom layer back to its original state with no highlighted
%spaces
BL=[2,1,2,1,2,1,2,1,27;
    1,2,1,2,1,2,1,2,27;
    2,1,2,1,2,1,2,1,27;
    1,2,1,2,1,2,1,2,27;
    2,1,2,1,2,1,2,1,27;
    1,2,1,2,1,2,1,2,27;
    2,1,2,1,2,1,2,1,27;
    1,2,1,2,1,2,1,2,27];

% Sets sprite matrix using the correspondence from the chessboard
% (turns the internal chessboard into a sprite matrix)
TL=[cb.correspond(@SpriteMapper), [99; 99; 47; 48; 40; 99; 99; 99]];
end
           
function SL = buildSL()
    global isdebug isforfeit isclear;
    SL = 99 * ones(8, 9);

    if isclear
        SL(3,9) = 37;
    end

    if isdebug
        SL(5,9) = 39;
    end

    if isforfeit
        SL(4,9) = 38;
    end
end
    
function [r,c, vmoves] = requestsel(bge, cb, BBL)
global isforfeit coord_forfeit isdebug coord_debug pgn TL BL sfx_blip sfx_bloc sfx_err sfx_sup;

%Initializes isvalidselection variable to 0
isvalidselection=0;

%Creates while loop for when isvalidselection is false (equal to 0)
while ~isvalidselection
    %Assigns 1x2 matrix that will get the coordinates of the
    %player's mouse input
    [r,c]=getMouseInput(bge);

    %Assigns the chess piece of the player's mouse input
    %coordinates to piece

    if c == 9
        if psame([r,c], coord_forfeit)
            bge.sound(sfx_blip);
            if ~isforfeit
                msgbox("Forfeit? (confirm)");
                pause(1);
                isforfeit = 1;

                drawScene(bge, BL, BBL, TL, buildSL());

            else
                cb.Checks = [2,0];
                msgbox("Forfeiting...");
                
                pause(1);
                pgn.smt("White forfeit");
                isforfeit = 2;
                break;
            end
        elseif psame([r,c], coord_debug)
            isdebug = ~isdebug;

            if isdebug
                bge.sound(sfx_blip);
            else
                bge.sound(sfx_err);
            end

            drawScene(bge, BL, BBL, TL, buildSL());
        end
    else
        piece=cb.get([r,c]);

        %Creates if statement for when iseabs(piece) is false (when the
        %selected space is not empty/occupied by a chess piece) and for
        %when piece.Player==1 (when the selected chess piece is white)
        if ~iseabs(piece) && piece.Player==1
            %Sets isvalidselection to 1
            bge.sound(sfx_sup);
            isvalidselection=1;
        else
            %Displays to the player that their choice is invalid, and
            %they must select a valid piece
            bge.sound(sfx_err);
            msgbox("Invalid piece. Please select a valid piece.")
            pause(2);
        end
    end
end

if isforfeit == 2
    vmoves = 0;
    r = 0;
    c = 0;
else
    %Sets variable vmoves to a collection of the indices of legal moves
    %for the selected chess piece
    vmoves=cb.rmoves([r,c]);

    %Changes the top layer sprite at the player's mouse input coordinates
    %to a highlighted version of that sprite
    TL(r,c)=TL(r,c)+12;

    %Creates for loop for the length of vmoves
    for i=1:length(vmoves)
        %Sets variable vmove for each index of vmoves
        vmove=vmoves{i};

        %Changes each legal space sprite on the chess board to a
        %highlighted space sprite
        BL(vmove(1),vmove(2))=28;
    end

    %Creates the new scene with the highlighted chess piece and highlighted
    %legal spaces
    drawScene(bge,BL,BBL,TL);
end
end

while isforfeit ~= 2
    %Creates if statement for when pturn is true
    if pturn
        if cb.Checks(1)
            msgbox("Check. You must move a piece to get out of check.")
            pause(2);
        end

        [r, c, vmoves] = requestsel(chess_game, cb, BBL);


        if isforfeit ~= 2
            %Initalizes variable isvalidmove to 0
            isvalidmove = 0;

 
            %Creates while loop for when isvalidmove is false (equal to 0)
            while ~isvalidmove
                isclear = 1;
         drawScene(chess_game, BL, BBL, TL, buildSL());
                %Assigns 1x2 matrix that will get the new coordinates of the
                %player's second mouse input
                [R,C] = getMouseInput(chess_game);

                %Assigns the chess piece of the player's mouse input
                %coordinates to the new space
                if C == 9
                    if psame([R,C], coord_clear)
                        chess_game.sound(sfx_blip);
                        resetLayers(cb);
                        isclear = 0;
                        drawScene(chess_game, BL, BBL, TL, buildSL());
                        [r, c, vmoves] = requestsel(chess_game, cb, BBL);

                    elseif psame([R,C], coord_debug)
                        isdebug = ~isdebug;

                        if isdebug
                            chess_game.sound(sfx_blip);
                        else
                            chess_game.sound(sfx_err);
                        end

                        drawScene(chess_game, BL, BBL, TL, buildSL());
                    end
                else
                    piece=cb.get([R,C]);

                    %Creates if statement for if vmoves contains the coordinates of the
                    %player's second mouse input
                    if has(vmoves,[R,C])
                        %Sets variable isvalidmove to 1
                        isvalidmove=1;
                    else
                        %Displays to the player that their choice is invalid, and they
                        %must select a valid space to move to
                        chess_game.sound(sfx_err);
                        msgbox("Invalid choice. Please select a valid move.")
                        pause(2);
                    end
                end
            end

            isclear = 0;
            drawScene(chess_game, BL, BBL, TL, buildSL());

            % Moves the piece from old to new position
            if ~iseabs(cb.pgnmove([r,c],[R,C], pgn))
                chess_game.sound(sfx_cap);
            else
                chess_game.sound(sfx_sdown);
            end

            % If white pawn moved to end of board (row 1), promote piece!!!
            if cb.get([R,C]) == WhitePawn && R == 1
                chess_game.sound(sfx_enighit);
                % Get the piece type they want.
                ptype = pieceprompt();

                % Prompt with engineering question and upgrade if correct.
                multipleChoiceQuiz(cb, [R,C], ptype);

                % Update PGN
                pgn.updpromo(ptype);
            end

            resetLayers(cb);

            %Creates the new scene with the selected chess piece in its new
            %position on the board and the chess board back to normal
            drawScene(chess_game,BL,BBL,TL,buildSL());
        end
    else
        if isdebug
            isvalidselection=0;

            %Creates while loop for when isvalidselection is false (equal to 0)
            while ~isvalidselection
                %Assigns 1x2 matrix that will get the coordinates of the
                %player's mouse input
                [r,c]=getMouseInput(chess_game);

                %Assigns the chess piece of the player's mouse input
                %coordinates to piece
                
                if c ~= 9
                    piece=cb.get([r,c]);

                    %Creates if statement for when iseabs(piece) is false (when the
                    %selected space is not empty/occupied by a chess piece) and for
                    %when piece.Player==1 (when the selected chess piece is white)
                    if ~iseabs(piece) && ~isempty(unwrap(cb.rmoves([r,c]), 1)) && piece.Player==2
                        chess_game.sound(sfx_chup);
                        %Sets isvalidselection to 1
                        isvalidselection=1;
                    else
                        %Displays to the player that their choice is invalid, and
                        %they must select a valid piece
                        chess_game.sound(sfx_err);
                        msgbox("Invalid piece. Please select a valid piece.")
                        pause(2);
                    end
                end


            end

            vmoves = cb.rmoves([r,c]);

            %Changes the top layer sprite at the player's mouse input coordinates
            %to a highlighted version of that sprite
            TL(r,c)=TL(r,c)+12;

            %Creates for loop for the length of vmoves
            for i=1:length(vmoves)
                %Sets variable vmove for each index of vmoves
                vmove=vmoves{i};

                %Changes each legal space sprite on the chess board to a
                %highlighted space sprite
                BL(vmove(1),vmove(2))=29;
            end

            drawScene(chess_game, BL, BBL, TL, buildSL());


            isvalidmove = 0;

            %Creates while loop for when isvalidmove is false (equal to 0)
            while ~isvalidmove

                [R,C]=getMouseInput(chess_game);

                if C ~= 9
                    piece=cb.get([R,C]);

                    %Creates if statement for if vmoves contains the coordinates of the
                    %player's second mouse input
                    if has(vmoves,[R,C])
                        %Sets variable isvalidmove to 1
                        isvalidmove=1;
                    else
                        chess_game.sound(sfx_err);
                        %Displays to the player that their choice is invalid, and they
                        %must select a valid space to move to
                        msgbox("Invalid choice. Please select a valid move.")
                        pause(2);
                    end
                end
            end

             resetLayers(cb);

            %Creates the new scene with the selected chess piece in its new
            %position on the board and the chess board back to normal
            drawScene(chess_game,BL,BBL,TL,buildSL());

            old = [r,c];
            new = [R,C];

        else
            if ~any(cb.Checks == 2)
                % The bot gets the next valid move.
                [old,new]=bot.nextmove([0,0]);
            end
        end

        % Do the bot's move.
        if ~iseabs(cb.pgnmove(old,new,pgn))
            chess_game.sound(sfx_cap);
        else
            chess_game.sound(sfx_sdown);
        end



        % If black pawn moved to end of board (row 8), promote to random
        % piece.
        if cb.get(new) == BlackPawn && new(1) == 8
            chess_game.sound(sfx_enighit);

            % Piece types and probability PDF.
            types = [ BlackQueen, BlackRook, BlackBishop, BlackKnight ];
            pdf = [ 0.7, 0.1, 0.1, 0.1 ];

            % Upgrade the piece to the selected one.
            selpiece = types(vrandp(pdf));
            cb.pow(new, selpiece);

            % Update PGN
            pgn.updpromo(selpiece.Type);
        end
    end

    % If white is checkmated (black wins)
    if any(cb.Checks == 2)
        if cb.Checks(1) == 2
            chess_game.sound(sfx_gameover);
            msgbox("Black wins!");
        else
            chess_game.sound(sfx_win);
            msgbox("White wins!");
        end

        pause(8)
        msgbox('Returning to command window...')
        pause(2)
        pgn_fpath = input("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nSave PGN to... ", 's');

        if ~isblank(pgn_fpath)
            pgn_fid = fopen(pgn_fpath, 'w');

            pgn_wname = input("White player's name... ", 's');
            pgn_bname = input("Black player's name... ", 's');
            pgn_event = input("Event... ", 's');

            if ~isblank(pgn_wname)
                pgn.setname(pgn_wname, 1);
            end

            if ~isblank(pgn_bname)
                pgn.setname(pgn_bname, 2);
            end

            if ~isblank(pgn_event)
                pgn.setevent(pgn_event);
            end

            fprintf(pgn_fid, "%s", pgn.compile());
            fclose(pgn_fid);
    
            chess_game.sound(sfx_enigapp);
            fprintf("\n\n. ݁₊ ⊹ . ݁˖ . ݁ Thanks for playing! PGN written to %s. ⟡ ݁₊ .\n\n\n", pgn_fpath);
        else
             chess_game.sound(sfx_enigapp);
            fprintf("\n\n. ݁₊ ⊹ . ݁˖ . ݁ Thanks for playing! PGN paste below ↴ ⟡ ݁₊ .\n\n%s\n\n\n", pgn.compile());
        end
       break;
    end



    % Update board sprites.
    TL=[cb.correspond(@SpriteMapper), [99; 99; 47; 48; 40; 99; 99; 99]];

    %Pauses the program for 0.5 seconds so the bot doesn't make its move
    %instantly after the player makes their move
    pause(.5);

    %Creates the new scene with the bot's chosen chess piece in its new
    %position on the board
    drawScene(chess_game,BL,BBL,TL,buildSL())

    %Sets variable pturn to false
    pturn=~pturn;

end

