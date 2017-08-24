from .base import Base


class Source(Base):
    
    def __init__(self, vim):
        super().__init___(vim)
        self.name = 'grammarous'
        self.kind = 'file'

        self.__buffer = self.vim.current.buffer.name

    def gather_candidates(self, context):
        result = self.vim.eval('b:grammarous_result')
        return result
