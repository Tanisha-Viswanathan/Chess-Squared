function multipleChoiceQuiz(chessboard, pos, ptype)
% Create a cell array of questions for each type of chess piece
questions_array = {
    % Queen questions
    {'Which engineered safety object was invented in 1959?',
    'What was the first animal in space?',
    'Which MATLAB variable is valid?',
    'Which operation is not done using a computer-controlled machine?',
    'What is a joule per second defined as?',
    'Which MATLAB command lists the current variable?',
    'Hybrid engineers manufacture what kind of colorful steel?',
    'There are 2 power stations in the world with capacity for more than 2,000 megawatts each. Which country?'};

    % Knight questions
    {'What is the command to insert data from a separate file to the current file?',
    'True or false- Computer engineers create software that can be used on a desktop, in cell phones and vehicles.',
    'Where did the first woman to graduate with a Ph.D. in engineering, Yun Hao Feng, obtain her degree from?',
    'True or false- Some planes can travel faster than the speed of sound?',
    'What is the correct way to display a number with 2 decimal places?',
    'What origin does the word “engineer” come from?',
    'Which relational operator does MATLAB not support?',
    'The expression 3*2^2 is equal to…'};

    % Rook questions
    {'What is the highest paying engineering discipline?',
    'How does a switch-case differ from an if-else statement?',
    'Which kitchen appliance was invented by accident?',
    'In MATLAB, the workspace used by a function is…',
    'The output of cat=[‘cat’’dog’] would be…',
    'Which conversion character is most appropriate to display a temperature using the fprintf command? outdoorTemp=67.9',
    'To determine whether an input is a MATLAB keyword, which command is used?',
    'The Wright brothers operated a bicycle repair shop in what Ohio city?'};

    % Bishop questions
    {'What is the oldest branch of engineering?',
    'Which subfield of engineering would be most helpful to someone working in a power plant?',
    'Which discipline of physical science would be most important for engineering working with engines, cooling systems and steam power?',
    'True or false- All “while” loops can be reformulated into “for” loops?',
    'Which was invented first?',
    'What are tin cans made of?',
    'Which function would generate a random number using normal distribution?',
    'What does the command “clear” do?'}
    };

% Define answer choices for each question along with the index of the correct answer
answers = {
    % Queen answers
    {{  {'Emergency Stop Button', 'Seat belt', 'Carbon monoxide detectors', 'Airbags in cars'}, 2},
    {  {'Dog', 'Monkey', 'Fruit Flies', 'Spider'}, 3},
    {  {'chess_game', 'chess.game', 'chess/game', 'chess.game'}, 1},
    {  {'Milling', 'Filling', 'Cutting', 'Splicing'}, 1},
    {  {'Watt', 'Volt', 'Ohm', 'Ampere'}, 1},
    {  {'whos', 'who', 'whose', 'whom'}, 2},
    {  {'Red steel', 'Blue steel', 'Green steel', 'Yellow steel'}, 3},
    {  {'China', 'Russia', 'India', 'Brazil'}, 3}},

    % Knight answers
    {{ {'load()', 'insert()', 'file()', 'call()'}, 1},
    {  {'True', 'False'}, 1},
    {  {'Stanford', 'Purdue', 'Ohio State', 'University of Wisconsin'}, 3},
    {  {'True', 'False'}, 1},
    {  {'%.2d', '%.2f', '%.2i', '%.2s'}, 2},
    {  {'Greek', 'Latin', 'French', 'Russian'}, 2},
    {  {'<=', '<<', '~=', '=='}, 2},
    {  {'12', '36', '25', '14'}, 1}},

    % Rook answers
    {{  {'Aerospace Engineering', 'Biomedical Engineering', 'Chemical Engineering', 'Computer Science Engineering'}, 3},
    {  {'User Prompt', 'Number of conditions', 'More Concise', 'Variable conditions'}, 1},
    {  {'Toaster', 'Microwave', 'Fridge', 'Stove'}, 2},
    {  {'General workspace', 'Separate workspace accessed by caller and function', 'Separate workspace accessed by function only', 'Reserved workspace for user-defined functions'}, 3},
    {  {'cat,dog', 'catdog', 'cat&dog', 'CatDog'}, 2},
    {  {'%c', '%d', '%f', '%s'}, 3},
    {  {'keyword', 'iskeyword', 'getkeyword', 'namekeyword'}, 2},
    {  {'Toledo', 'Columbus', 'Youngstown', 'Dayton'}, 4}},

    % Bishop answers
    {{  {'Mechanical Engineering', 'Aerospace Engineering', 'Civil Engineering', 'Chemical Engineering'}, 3},
    {  {'Nuclear Engineering', 'Electrical Engineering', 'Chemical Engineering', 'Industrial Engineering'}, 1},
    {  {'Gas Laws', 'Thermodynamics', 'Classical Mechanics', 'Kinetics'}, 2},
    {  {'True', 'False'}, 2},
    {  {'The Telephone', 'The Light Bulb', 'The Airplane', 'The Radio'}, 1},
    {  {'Alloy of copper and nickel', 'Carbon', 'Alloy of carbon and Iron', 'Nickel'}, 3},
    {  {'rand', 'randi', 'randn', 'randin'}, 3},
    {  {'Clear the command window', 'Clear all variables from workspace', 'Clear the script file', 'Both A and B'}, 2}};
    };

% Select the questions based on the piece type
switch ptype
    case PieceType.Queen
        piece_questions = questions_array{1};
        piece_answers = answers{1};
    case PieceType.Knight
        piece_questions = questions_array{2};
        piece_answers = answers{2};
    case PieceType.Rook
        piece_questions = questions_array{3};
        piece_answers = answers{3};
    case PieceType.Bishop
        piece_questions = questions_array{4};
        piece_answers = answers{4};
end

% Create a figure window for the quiz
fig = figure('Position', [100, 100, 400, 400], 'MenuBar', 'none', 'Name', 'Multiple Choice Quiz', 'NumberTitle', 'off', 'Color', [0.9, 0.9, 0.9]);

% Remove x-axis & y-axis from the figure window for the quiz
set(gca, 'Visible', 'off')

% Set the figure title
title('Select the Correct Answer', 'FontSize', 16, 'FontWeight', 'bold');
movegui(fig, 'center');  % Move the figure to the center of the screen

% Pick index of random choice
randindex = randi(8);

% Get question and answer pair for index
question = piece_questions(randindex);
anspair = unwrap(piece_answers(randindex));

% Extract choices and index.
anschoices = anspair{1};
ansindex = anspair{2};


% Display each question and options
uicontrol('Style', 'text', 'String', question, 'Position', [50, 250 - 70, 300, 50], 'FontSize', 10);
for j = 1:length(anschoices)
    uicontrol('Style', 'radiobutton', 'String', anschoices{j}, 'Position', [50, 200 - 70 - j * 30, 300, 30], ...
        'FontSize', 10, 'Callback', @(src, event) checkAnswerThenUpdate(chessboard, pos, ptype, ansindex, j, anschoices));
end

% Function to check and display goodness of answer, upgrade piece if
% correct.
function checkAnswerThenUpdate(chessboard, pos, ptype, correct_answer_index, selected_answer_index, options)
    if selected_answer_index == correct_answer_index
        msg = 'Correct!';

        % Get the player of the piece at position (pawn that promoted)
        player = chessboard.get(pos).Player;

        % Create overwrite piece
        owpiece = ChessPiece(ptype, player);

        % Overwrite the selected piece with the delicious piece
        chessboard.pow(pos, owpiece);
    else
        msg = ['Incorrect! The correct answer is: ', options{correct_answer_index}];
        close(fig);
    end
    
    % Display the result in a message box
    msgbox(msg, 'Result', 'modal');
end

end