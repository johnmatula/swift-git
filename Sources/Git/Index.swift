import Cgit2
import SystemPackage

public struct Index {
  let _object: ManagedGitObject

  public init() throws {
    let callbacks = GitCallbacks(free: git_index_free)
    self._object = try .create(withCallbacks: callbacks, operation: "git_index_new") { pointer in
      git_index_new(&pointer)
    }
  }

  public init(repository: Repository) throws {
    let callbacks = GitCallbacks(free: git_index_free)
    self._object = try .create(withCallbacks: callbacks, operation: "git_repository_index") { pointer in
      repository._object.withUnsafePointer { repository in
        git_repository_index(&pointer, repository)
      }
    }
  }

  public subscript(path: FilePath) -> Index.Entry? {
    _object.withUnsafePointer { index in
      return git_index_get_bypath(index, path.string, GIT_INDEX_STAGE_NORMAL.rawValue)
        .map(Entry.init)
    }
  }
}

extension Index {
  public func readTree<Reference: Git.Reference>(at reference: Reference) throws {
    try read(Tree(reference))
  }

  public func read(_ tree: Tree) throws {
    let code = _object.withUnsafePointer { index in
      tree._object.withUnsafePointer { tree in
        git_index_read_tree(index, tree)
      }
    }
    try GitError.check(code, operation: "git_index_read_tree")
  }
}

extension Index {
  public struct Entry: Hashable {
    public let id: ObjectID
    public let path: FilePath

    fileprivate init(_ entry: UnsafePointer<git_index_entry>) {
      let entry = entry.pointee
      self.id = ObjectID(entry.id)
      self.path = FilePath(cString: entry.path)
    }
  }

  public var entries: EntryView {
    EntryView(index: self)
  }

  public struct EntryView: RandomAccessCollection {
    fileprivate var index: Index

    public var startIndex: Int {
      0
    }

    public var endIndex: Int {
      index._object.withUnsafePointer(git_index_entrycount)
    }

    public subscript(position: Int) -> Index.Entry {
      index._object.withUnsafePointer { index in
        Entry(git_index_get_byindex(index, position))
      }
    }
  }
}
