/**
 * アーキテクチャ境界 Fitness Function（Java / Kotlin 用の最小サンプル / ArchUnit）。
 *
 * 使い方: テストソース（src/test/java/...）に配置し、パッケージ名を実プロジェクトに
 * 合わせて直す。テストランナーで通常のテストとして実行される（CI で自動的に境界検査になる）。
 *
 *   testImplementation 'com.tngtech.archunit:archunit-junit5:1.3.0'
 *
 * ルールの意味（正本: .claude/skills/architecture-design/guide.md「依存性のルール」）:
 *   依存はすべて内向き。外側のレイヤだけが内側にアクセスできる。
 */
package com.example.app;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

@AnalyzeClasses(packages = "com.example.app")
class ArchitectureTest {

    @ArchTest
    static final ArchRule 依存はすべて内向き = layeredArchitecture()
            .consideringAllDependencies()
            .layer("Entities").definedBy("..entities..")
            .layer("UseCases").definedBy("..usecases..")
            .layer("Adapters").definedBy("..adapters..")
            .layer("Infrastructure").definedBy("..infrastructure..")
            // 内側は外側からのみアクセスされる（内側から外側への依存は落ちる）
            .whereLayer("Adapters").mayOnlyBeAccessedByLayers("Infrastructure")
            .whereLayer("UseCases").mayOnlyBeAccessedByLayers("Adapters", "Infrastructure")
            .whereLayer("Entities").mayOnlyBeAccessedByLayers("UseCases", "Adapters", "Infrastructure");
}
