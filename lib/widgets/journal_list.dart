import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:journal/note.dart';
import 'package:journal/state_container.dart';
import 'package:journal/utils.dart';

typedef void NoteSelectedFunction(int noteIndex);

class JournalList extends StatelessWidget {
  final NoteSelectedFunction noteSelectedFunction;
  final List<Note> notes;

  JournalList({
    @required this.notes,
    @required this.noteSelectedFunction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      separatorBuilder: (context, index) {
        return Divider(
          color: Theme.of(context).primaryColorLight,
        );
      },
      itemBuilder: (context, i) {
        if (i >= notes.length) {
          return null;
        }

        var note = notes[i];
        return Dismissible(
          key: Key(note.filePath),
          child: _buildRow(context, note, i),
          background: Container(color: Theme.of(context).accentColor),
          onDismissed: (direction) {
            final stateContainer = StateContainer.of(context);
            stateContainer.removeNote(note);

            Scaffold.of(context)
                .showSnackBar(buildUndoDeleteSnackbar(context, note, i));
          },
        );
      },
      itemCount: notes.length,
    );
  }

  Widget _buildRow(BuildContext context, Note journal, int noteIndex) {
    var formatter = DateFormat('dd MMM, yyyy - EE');
    var title = formatter.format(journal.created);

    var timeFormatter = DateFormat('Hm');
    var time = timeFormatter.format(journal.created);

    var body = journal.body;
    body = body.replaceAll("\n", " ");

    var textTheme = Theme.of(context).textTheme;

    var tile = ListTile(
      key: ValueKey(journal.filePath),
      isThreeLine: true,
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        children: <Widget>[
          SizedBox(height: 4.0),
          Text(time, style: textTheme.body1),
          SizedBox(height: 4.0),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.body1,
          ),
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
      onTap: () => noteSelectedFunction(noteIndex),
    );

    return Padding(
      padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: tile,
    );
  }
}
