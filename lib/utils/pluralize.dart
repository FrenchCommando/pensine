String pluralize(int n, String singular, [String? plural]) =>
    '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';
