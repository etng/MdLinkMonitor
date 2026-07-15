import Testing
@testable import MdMCore

@Test
func markdownLinkExtractionSingle() {
    let input = "Use [Repo](https://github.com/apple/swift) now"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.count == 1)
    #expect(links[0] == MarkdownLink(label: "Repo", url: "https://github.com/apple/swift"))
}

@Test
func markdownLinkExtractionMultiple() {
    let input = "[A](https://github.com/o1/r1) and [B](https://github.com/o2/r2)"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.count == 2)
    #expect(links[1].label == "B")
}

@Test
func markdownLinkExtractionIgnoresRelativeURLs() {
    let input = "* [ ] [54K](/yeahwu404/status/2034250073727795576/analytics)"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.isEmpty)
}

@Test
func markdownLinkExtractionStripsUTMQueryItems() {
    let input = "[Repo](https://example.com/post?utm_source=rss&utm_medium=email&id=42#top)"
    let links = MarkdownLinkExtractor.extract(from: input)

    #expect(links.count == 1)
    #expect(links[0] == MarkdownLink(label: "Repo", url: "https://example.com/post?id=42#top"))
}

@Test
func githubRepoParsesAndNormalizes() {
    let parsed = GitHubRepositoryParser.parse(from: "https://github.com/owner/repo.git?tab=readme#top")

    #expect(parsed?.owner == "owner")
    #expect(parsed?.name == "repo")
    #expect(parsed?.host == "github.com")
    #expect(parsed?.canonicalURL == "https://github.com/owner/repo")
    #expect(parsed?.cloneURL == "https://github.com/owner/repo.git")
    #expect(parsed?.dailyDedupKey == "github.com/owner/repo")
}

@Test
func githubRepoParsesBrowserReadmeTabURL() {
    let parsed = GitHubRepositoryParser.parse(from: "https://github.com/DanielLavrushin/b4?tab=readme-ov-file")

    #expect(parsed?.owner == "DanielLavrushin")
    #expect(parsed?.name == "b4")
    #expect(parsed?.canonicalURL == "https://github.com/DanielLavrushin/b4")
    #expect(parsed?.cloneURL == "https://github.com/DanielLavrushin/b4.git")
}

@Test
func githubRepoRejectsNonRepoOrPath() {
    #expect(GitHubRepositoryParser.parse(from: "https://github.com/owner") == nil)
    #expect(GitHubRepositoryParser.parse(from: "https://github.com/owner/repo/issues") == nil)
    #expect(GitHubRepositoryParser.parse(from: "http://github.com/owner/repo") == nil)
    #expect(GitHubRepositoryParser.parse(from: "https://example.com/owner/repo") == nil)
}

@Test
func genericGitRepositoryParserSupportsGitLab() {
    let parsed = GitRepositoryParser.parse(
        from: "https://gitlab.com/group/project/-/issues/1",
        allowedDomains: ["github.com", "gitlab.com"]
    )
    #expect(parsed == nil)

    let repoParsed = GitRepositoryParser.parse(
        from: "https://gitlab.com/group/project?tab=readme#x",
        allowedDomains: ["github.com", "gitlab.com"]
    )
    #expect(repoParsed?.host == "gitlab.com")
    #expect(repoParsed?.canonicalURL == "https://gitlab.com/group/project")
}

@Test
func markdownTaskLineBuilderWorks() {
    let line = MarkdownTaskLineBuilder.makeLine(label: "Swift", repositoryURL: "https://github.com/apple/swift")
    #expect(line == "* [ ] [Swift](https://github.com/apple/swift)")
}

@Test
func markdownTaskLineBuilderAppendsAnnotation() {
    let line = MarkdownTaskLineBuilder.makeLine(
        label: "AIChatIndex",
        repositoryURL: "https://chromewebstore.google.com/detail/aichatindex/kgaaloljjidblambloblebocaobjjmlb",
        annotation: "AI聊天目录，快速回溯，精准定位。"
    )
    #expect(line == "* [ ] [AIChatIndex](https://chromewebstore.google.com/detail/aichatindex/kgaaloljjidblambloblebocaobjjmlb) - AI聊天目录，快速回溯，精准定位。")
}

@Test
func absoluteWebURLNormalizeRemovesOnlyUTMItems() {
    let normalized = AbsoluteWebURL.normalize("https://example.com/post?utm_source=rss&utm_campaign=spring#top")

    #expect(normalized == "https://example.com/post#top")
}
