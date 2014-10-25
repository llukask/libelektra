#ifndef CUTKEYCOMMAND_H
#define CUTKEYCOMMAND_H

#include <QUndoCommand>
#include "treeviewmodel.hpp"

class CutKeyCommand : public QUndoCommand
{
public:
    explicit CutKeyCommand(QString type, TreeViewModel *model, ConfigNode *source, ConfigNode *target, int index, QUndoCommand *parent = 0);

    virtual void undo();
    virtual void redo();

private:

    TreeViewModel   *m_model;
    ConfigNode      *m_source;
    ConfigNode      *m_target;
    int              m_sourceIndex;
    int              m_targetIndex;
};

#endif // CUTKEYCOMMAND_H
