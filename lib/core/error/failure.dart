class Failure {
  final String message;
  final String? code;

  Failure(this.message, {this.code});

  @override
  String toString() => message;
}

/// Một class tiện ích để bọc kết quả trả về, có thể là Thành công (Success) hoặc Thất bại (Error)
class Result<T> {
  final T? _data;
  final Failure? _failure;

  // Private constructor
  Result._(this._data, this._failure);

  // Khởi tạo trạng thái Thành công
  factory Result.success(T data) => Result._(data, null);

  // Khởi tạo trạng thái Thất bại
  factory Result.error(Failure failure) => Result._(null, failure);

  bool get isSuccess => _failure == null;
  bool get isError => _failure != null;

  T get data => _data!;
  Failure get failure => _failure!;
}
